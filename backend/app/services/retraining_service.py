"""Automatic complaint-priority model retraining service."""

import csv
import os
import shutil
import tempfile
from datetime import datetime, timedelta, timezone
from pathlib import Path

from flask import current_app
from sqlalchemy.exc import IntegrityError

from app.database import db
from app.ml.priority_model import ComplaintPriorityModel
from app.ml.train_priority_model import train_and_evaluate
from app.models import Complaint, MlRetrainingBatch, MlRetrainingItem


class RetrainingService:
    """Claim eligible complaints, retrain, evaluate, and deploy safely."""

    BATCH_SIZE = 10
    DELAY_HOURS = 24
    TRAINING_STATUS = 'TRAINING'
    EVALUATED_STATUS = 'EVALUATED'
    DEPLOYED_STATUS = 'DEPLOYED'
    FAILED_STATUS = 'FAILED'
    DATASET_COLUMNS = [
        'Complaint Description',
        'Priority Level',
        'source',
    ]

    @staticmethod
    def _utc_now(reference_time=None):
        value = reference_time or datetime.now(timezone.utc)
        if value.tzinfo is not None:
            value = value.astimezone(timezone.utc).replace(tzinfo=None)
        return value

    @classmethod
    def _paths(cls):
        backend_root = Path(__file__).resolve().parents[2]
        dataset_path = backend_root / 'datasets' / 'CampusHive_500_training_dataset.csv'
        model_path = backend_root / 'app' / 'ml' / 'priority_model.joblib'
        candidate_path = backend_root / 'app' / 'ml' / 'priority_model.candidate.joblib'
        return dataset_path, model_path, candidate_path

    @classmethod
    def _claim_batch(cls, reference_time=None):
        now = cls._utc_now(reference_time)
        delay_hours = int(current_app.config.get(
            'ML_RETRAINING_DELAY_HOURS',
            cls.DELAY_HOURS,
        ))
        batch_size = int(current_app.config.get(
            'ML_RETRAINING_BATCH_SIZE',
            cls.BATCH_SIZE,
        ))
        eligible_before = now - timedelta(hours=delay_hours)

        # Clear any SQLAlchemy autobegin transaction before starting the claim.
        if db.session().in_transaction():
            db.session.rollback()

        try:
            db.session.begin()
            eligible_query = Complaint.query.filter(
                Complaint.created_at <= eligible_before,
                Complaint.final_priority.in_(['LOW', 'MEDIUM', 'HIGH']),
                ~Complaint.ml_retraining_item.any(),
            ).order_by(
                Complaint.created_at.asc(),
                Complaint.complaint_id.asc(),
            )
            eligible_count = eligible_query.count()
            if eligible_count < batch_size:
                db.session.rollback()
                return None

            complaints = eligible_query.with_for_update().limit(batch_size).all()
            if len(complaints) != batch_size:
                db.session.rollback()
                return None

            batch = MlRetrainingBatch(
                eligible_count=eligible_count,
                selected_count=batch_size,
                status=cls.TRAINING_STATUS,
            )
            db.session.add(batch)
            db.session.flush()

            snapshots = []
            for complaint in complaints:
                eligible_at = complaint.created_at + timedelta(hours=delay_hours)
                item = MlRetrainingItem(
                    batch_id=batch.batch_id,
                    complaint_id=complaint.complaint_id,
                    eligible_at=eligible_at,
                    description_snapshot=complaint.description,
                    priority_label=complaint.final_priority,
                    source='REAL',
                )
                db.session.add(item)
                snapshots.append({
                    'Complaint Description': complaint.description,
                    'Priority Level': complaint.final_priority,
                    'source': 'REAL',
                })

            db.session.flush()
            db.session.commit()
            return batch.batch_id, snapshots
        except IntegrityError:
            db.session.rollback()
            return None
        except Exception:
            db.session.rollback()
            raise

    @classmethod
    def _write_dataset_candidate(cls, snapshots, dataset_path):
        if not dataset_path.exists():
            raise FileNotFoundError(f'Dataset not found: {dataset_path}')

        temporary = tempfile.NamedTemporaryFile(
            mode='w',
            newline='',
            encoding='utf-8',
            dir=dataset_path.parent,
            suffix='.csv',
            delete=False,
        )
        temporary_path = Path(temporary.name)
        temporary.close()
        try:
            with dataset_path.open('r', newline='', encoding='utf-8') as source:
                reader = csv.DictReader(source)
                if not set(cls.DATASET_COLUMNS).issubset(reader.fieldnames or []):
                    raise ValueError(
                        f'Unexpected training dataset columns: {reader.fieldnames}',
                    )

                with temporary_path.open('w', newline='', encoding='utf-8') as target:
                    writer = csv.DictWriter(
                        target,
                        fieldnames=cls.DATASET_COLUMNS,
                    )
                    writer.writeheader()
                    for row in reader:
                        writer.writerow({
                            column: row[column]
                            for column in cls.DATASET_COLUMNS
                        })

            with temporary_path.open('a', newline='', encoding='utf-8') as target:
                writer = csv.DictWriter(target, fieldnames=cls.DATASET_COLUMNS)
                for snapshot in snapshots:
                    writer.writerow(snapshot)
            return temporary_path
        except Exception:
            temporary_path.unlink(missing_ok=True)
            raise

    @staticmethod
    def _validate_candidate(model_path):
        model = ComplaintPriorityModel(str(model_path))
        for description in (
            'Electrical sparks are coming from a laboratory socket',
            'WiFi keeps disconnecting',
            'Minor classroom maintenance issue',
        ):
            result = model.predict(description)
            if result['priority'] not in {'low', 'medium', 'high'}:
                raise ValueError(f'Invalid candidate priority: {result["priority"]}')
            if not 0.0 <= result['confidence'] <= 1.0:
                raise ValueError('Candidate confidence is outside 0..1')

    @classmethod
    def _deploy(cls, dataset_candidate, dataset_path, candidate_path, model_path):
        dataset_backup_file = tempfile.NamedTemporaryFile(
            prefix='campushive-dataset-',
            suffix='.csv',
            dir=dataset_path.parent,
            delete=False,
        )
        dataset_backup = Path(dataset_backup_file.name)
        dataset_backup_file.close()
        model_backup = Path(str(model_path) + '.backup')
        staged_candidate_file = tempfile.NamedTemporaryFile(
            prefix='campushive-model-candidate-',
            suffix='.joblib',
            dir=model_path.parent,
            delete=False,
        )
        staged_candidate = Path(staged_candidate_file.name)
        staged_candidate_file.close()
        shutil.copyfile(dataset_path, dataset_backup)
        shutil.copyfile(model_path, model_backup)
        try:
            shutil.copyfile(candidate_path, staged_candidate)
            os.replace(dataset_candidate, dataset_path)
            os.replace(staged_candidate, model_path)
        except Exception:
            shutil.copyfile(dataset_backup, dataset_path)
            shutil.copyfile(model_backup, model_path)
            raise
        finally:
            dataset_backup.unlink(missing_ok=True)
            staged_candidate.unlink(missing_ok=True)

    @classmethod
    def check_and_retrain(cls, reference_time=None):
        """Run one batch check; reference_time is intended for manual tests."""
        claim = cls._claim_batch(reference_time=reference_time)
        if claim is None:
            return None

        batch_id, snapshots = claim
        dataset_path, model_path, candidate_path = cls._paths()
        dataset_candidate = None
        try:
            dataset_candidate = cls._write_dataset_candidate(snapshots, dataset_path)
            metrics = train_and_evaluate(dataset_candidate, candidate_path)
            cls._validate_candidate(candidate_path)

            batch = db.session.get(MlRetrainingBatch, batch_id)
            overall = metrics['overall_test']
            batch.accuracy = overall['accuracy']
            batch.macro_precision = overall['precision_macro']
            batch.macro_recall = overall['recall_macro']
            batch.macro_f1 = overall['f1_macro']
            batch.candidate_artifact_path = str(candidate_path)
            batch.status = cls.EVALUATED_STATUS
            db.session.commit()

            cls._deploy(
                dataset_candidate,
                dataset_path,
                candidate_path,
                model_path,
            )
            batch.status = cls.DEPLOYED_STATUS
            db.session.commit()
            return metrics
        except Exception as exc:
            db.session.rollback()
            batch = db.session.get(MlRetrainingBatch, batch_id)
            if batch is not None:
                batch.status = cls.FAILED_STATUS
                batch.error_message = str(exc)
                db.session.commit()
            raise
        finally:
            if dataset_candidate is not None:
                dataset_candidate.unlink(missing_ok=True)
            candidate_path.unlink(missing_ok=True)
