"""Tests for PriorityService priority calculation and voting escalation."""

import pytest
from datetime import datetime, timedelta
from app.services.priority_service import PriorityService


class DummyDepartment:
    """Mock department with priority SLA hours."""
    priority_high_hours = 24
    priority_medium_hours = 72
    priority_low_hours = 168


class DummyComplaint:
    """Mock complaint object for update_complaint_priority testing."""
    def __init__(self, description="Test issue", ml_priority=None, support_count=0):
        self.complaint_id = 1
        self.department_id = 1
        self.department = DummyDepartment()
        self.description = description
        self.ml_priority = ml_priority
        self.final_priority = None
        self.support_count = support_count
        self.deadline = None
        self.created_at = datetime(2026, 1, 1, 12, 0, 0)


# =====================================================================
# 1. Exact boundary tests for LOW ML priority: 0, 9, 10, 19, 20, 29, 30
# =====================================================================

@pytest.mark.parametrize(
    "votes,expected",
    [
        (0, "LOW"),
        (9, "LOW"),
        (10, "MEDIUM"),
        (19, "MEDIUM"),
        (20, "HIGH"),
        (29, "HIGH"),
        (30, "HIGH"),
    ],
)
def test_ml_low_boundary_escalation(votes, expected):
    """LOW predictions remain LOW for 0-9 votes, escalate to MEDIUM for 10-19, and HIGH for 20+."""
    assert PriorityService.calculate_final_priority("LOW", votes) == expected


# =====================================================================
# 2. Exact boundary tests for MEDIUM ML priority: 0, 9, 10, 19, 20, 29, 30
# =====================================================================

@pytest.mark.parametrize(
    "votes,expected",
    [
        (0, "MEDIUM"),
        (9, "MEDIUM"),
        (10, "HIGH"),
        (19, "HIGH"),
        (20, "HIGH"),
        (29, "HIGH"),
        (30, "HIGH"),
    ],
)
def test_ml_medium_boundary_escalation(votes, expected):
    """MEDIUM predictions remain at least MEDIUM for 0-9 votes, and escalate to HIGH for 10+."""
    assert PriorityService.calculate_final_priority("MEDIUM", votes) == expected


# =====================================================================
# 3. Exact boundary tests for HIGH ML priority: 0, 9, 10, 19, 20, 29, 30
# =====================================================================

@pytest.mark.parametrize(
    "votes",
    [0, 9, 10, 19, 20, 29, 30, 50, 100],
)
def test_ml_high_never_downgraded(votes):
    """HIGH predictions always remain HIGH regardless of vote count."""
    assert PriorityService.calculate_final_priority("HIGH", votes) == "HIGH"


# =====================================================================
# 4. Negative and null vote count handling
# =====================================================================

@pytest.mark.parametrize(
    "ml_priority,expected",
    [
        ("LOW", "LOW"),
        ("MEDIUM", "MEDIUM"),
        ("HIGH", "HIGH"),
    ],
)
def test_negative_vote_counts_normalized_to_zero(ml_priority, expected):
    """Negative vote counts should be treated as 0 votes and never downgrade ML priority."""
    assert PriorityService.calculate_final_priority(ml_priority, -1) == expected
    assert PriorityService.calculate_final_priority(ml_priority, -10) == expected
    assert PriorityService.calculate_final_priority(ml_priority, None) == expected


# =====================================================================
# 5. Votes beyond 30
# =====================================================================

@pytest.mark.parametrize(
    "ml_priority",
    ["LOW", "MEDIUM", "HIGH"],
)
def test_votes_beyond_thirty_remain_high(ml_priority):
    """30+ votes should maintain HIGH priority without error."""
    assert PriorityService.calculate_final_priority(ml_priority, 35) == "HIGH"
    assert PriorityService.calculate_final_priority(ml_priority, 100) == "HIGH"


# =====================================================================
# 6. Case insensitivity and whitespace handling
# =====================================================================

def test_priority_case_insensitivity():
    """calculate_final_priority should handle lowercase, mixed-case, and whitespace."""
    assert PriorityService.calculate_final_priority("low", 0) == "LOW"
    assert PriorityService.calculate_final_priority("Medium", 0) == "MEDIUM"
    assert PriorityService.calculate_final_priority("  HIGH  ", 0) == "HIGH"
    assert PriorityService.calculate_final_priority("low", 10) == "MEDIUM"
    assert PriorityService.calculate_final_priority("medium", 10) == "HIGH"


# =====================================================================
# 7. Invalid ML priority and invalid vote count inputs
# =====================================================================

@pytest.mark.parametrize(
    "invalid_priority",
    ["CRITICAL", "URGENT", "UNKNOWN", "", None, 123],
)
def test_invalid_ml_priority_raises_value_error(invalid_priority):
    """Unsupported or non-string priority values must raise ValueError."""
    with pytest.raises(ValueError, match="Unsupported ML priority"):
        PriorityService.calculate_final_priority(invalid_priority, 0)


def test_invalid_support_count_raises_value_error():
    """Non-convertible vote counts must raise ValueError."""
    with pytest.raises(ValueError, match="Invalid support_count"):
        PriorityService.calculate_final_priority("LOW", "not_a_number")


# =====================================================================
# 8. Recalculation on complaint instances (recalculating priority & deadline)
# =====================================================================

def test_recalculating_priority_after_additional_votes():
    """Test full lifecycle of a complaint receiving additional votes."""
    complaint = DummyComplaint(
        description="Water fountain leaking on ground floor",
        ml_priority="LOW",
        support_count=0,
    )

    # Initial state (0 votes)
    PriorityService.update_complaint_priority(complaint, recalculate_ml=False)
    assert complaint.final_priority == "LOW"
    assert complaint.deadline == complaint.created_at + timedelta(hours=168)

    # Escalation to 9 votes (still LOW)
    complaint.support_count = 9
    PriorityService.update_complaint_priority(complaint, recalculate_ml=False)
    assert complaint.final_priority == "LOW"
    assert complaint.deadline == complaint.created_at + timedelta(hours=168)

    # Escalation to 10 votes (escalates to MEDIUM)
    complaint.support_count = 10
    PriorityService.update_complaint_priority(complaint, recalculate_ml=False)
    assert complaint.final_priority == "MEDIUM"
    assert complaint.deadline == complaint.created_at + timedelta(hours=72)

    # Escalation to 19 votes (remains MEDIUM)
    complaint.support_count = 19
    PriorityService.update_complaint_priority(complaint, recalculate_ml=False)
    assert complaint.final_priority == "MEDIUM"
    assert complaint.deadline == complaint.created_at + timedelta(hours=72)

    # Escalation to 20 votes (escalates to HIGH)
    complaint.support_count = 20
    PriorityService.update_complaint_priority(complaint, recalculate_ml=False)
    assert complaint.final_priority == "HIGH"
    assert complaint.deadline == complaint.created_at + timedelta(hours=24)

    # Escalation to 30+ votes (remains HIGH)
    complaint.support_count = 35
    PriorityService.update_complaint_priority(complaint, recalculate_ml=False)
    assert complaint.final_priority == "HIGH"
    assert complaint.deadline == complaint.created_at + timedelta(hours=24)


# =====================================================================
# 9. Support score helper verification
# =====================================================================

def test_calculate_support_score():
    """calculate_support_score properly normalizes 0..30 votes."""
    assert PriorityService.calculate_support_score(0) == 0.0
    assert PriorityService.calculate_support_score(-5) == 0.0
    assert PriorityService.calculate_support_score(15) == 0.5
    assert PriorityService.calculate_support_score(30) == 1.0
    assert PriorityService.calculate_support_score(50) == 1.0
