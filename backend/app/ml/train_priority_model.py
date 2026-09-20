"""Train and evaluate the CampusHive complaint priority model."""

import argparse
import json
from pathlib import Path

import pandas as pd
from sklearn.metrics import (
    accuracy_score,
    confusion_matrix,
    f1_score,
    precision_score,
    recall_score,
)
from sklearn.model_selection import train_test_split

from app.ml.priority_model import ComplaintPriorityModel


DATASET_COLUMNS = (
    'Complaint Description',
    'Priority Level',
    'source',
)
LABELS = ['LOW', 'MEDIUM', 'HIGH']


def _metrics(actual, predicted):
    return {
        'count': len(actual),
        'accuracy': float(accuracy_score(actual, predicted)),
        'precision_macro': float(
            precision_score(
                actual,
                predicted,
                labels=LABELS,
                average='macro',
                zero_division=0,
            ),
        ),
        'recall_macro': float(
            recall_score(
                actual,
                predicted,
                labels=LABELS,
                average='macro',
                zero_division=0,
            ),
        ),
        'f1_macro': float(
            f1_score(
                actual,
                predicted,
                labels=LABELS,
                average='macro',
                zero_division=0,
            ),
        ),
        'confusion_matrix': confusion_matrix(
            actual,
            predicted,
            labels=LABELS,
        ).tolist(),
    }


def train_and_evaluate(dataset_path, model_path):
    """Train the model and return overall and REAL-record metrics."""
    dataset = pd.read_csv(dataset_path)
    missing_columns = set(DATASET_COLUMNS) - set(dataset.columns)
    if missing_columns:
        raise ValueError(f'Missing dataset columns: {sorted(missing_columns)}')

    descriptions = dataset['Complaint Description'].fillna('').astype(str)
    priorities = (
        dataset['Priority Level']
        .fillna('')
        .astype(str)
        .str.strip()
        .str.upper()
    )
    if not priorities.isin(LABELS).all():
        invalid = sorted(set(priorities[~priorities.isin(LABELS)]))
        raise ValueError(f'Invalid priority labels: {invalid}')

    (
        train_descriptions,
        test_descriptions,
        train_priorities,
        test_priorities,
    ) = train_test_split(
        descriptions,
        priorities,
        test_size=0.2,
        random_state=42,
        stratify=priorities,
    )

    model = ComplaintPriorityModel()
    model.train(train_descriptions, train_priorities)
    model.save_model(model_path)

    test_predictions = [
        model.predict(description)['priority'].upper()
        for description in test_descriptions
    ]
    overall_metrics = _metrics(test_priorities.tolist(), test_predictions)

    real_mask = (
        dataset['source'].astype(str).str.strip().str.upper() == 'REAL'
    )
    real_descriptions = descriptions[real_mask]
    real_priorities = priorities[real_mask]
    real_predictions = [
        model.predict(description)['priority'].upper()
        for description in real_descriptions
    ]

    return {
        'dataset_rows': len(dataset),
        'training_rows': len(train_descriptions),
        'test_rows': len(test_descriptions),
        'class_counts': priorities.value_counts().reindex(LABELS).to_dict(),
        'real_rows': len(real_descriptions),
        'real_evaluation_note': (
            'REAL records were evaluated as a separate diagnostic set using '
            'the trained model; they were not force-split because the subset '
            'is small.'
        ),
        'overall_test': overall_metrics,
        'real_all_records': _metrics(
            real_priorities.tolist(),
            real_predictions,
        ),
        'model_path': str(Path(model_path).resolve()),
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('dataset', type=Path)
    parser.add_argument('model', type=Path)
    args = parser.parse_args()
    result = train_and_evaluate(args.dataset, args.model)
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
