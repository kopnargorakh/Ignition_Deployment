# -*- coding: utf-8 -*-
import unittest

from Mustry.Domain.Production.ProductionOrderAggregate import ProductionOrder
from Mustry.Domain.Production.ProductionOrderAggregate import ProductionOrderLine


class TestProductionOrder(unittest.TestCase):

    def setUp(self):
        """Set up reusable test data."""
        self.order = ProductionOrder(
            id_=1,
            orderNumber="PO-001",
            description="Test Production Order"
        )
        self.line1 = ProductionOrderLine(lineNo=1, productCode="PROD-A", quantity=10)
        self.line2 = ProductionOrderLine(lineNo=2, productCode="PROD-B", quantity=20)

    # --------------------- Initialization Tests ---------------------

    def test_initialization_defaults(self):
        """Test that a ProductionOrder initializes with correct default values."""
        self.assertEqual(self.order.id_, 1)
        self.assertEqual(self.order.orderNumber, "PO-001")
        self.assertEqual(self.order.description, "Test Production Order")
        self.assertEqual(self.order.status, ProductionOrder.PLANNED)
        self.assertEqual(len(self.order.lines), 0)

    def test_initialization_with_custom_status(self):
        """Test initialization with a custom status."""
        order = ProductionOrder(
            orderNumber="PO-002",
            status=ProductionOrder.IN_PROGRESS
        )
        self.assertEqual(order.status, ProductionOrder.IN_PROGRESS)

    # --------------------- Validation Tests ---------------------

    def test_order_number_cannot_be_none(self):
        """Test that order number cannot be None."""
        with self.assertRaises(ValueError):
            ProductionOrder(orderNumber=None)

    def test_order_number_cannot_be_whitespace(self):
        """Test that order number cannot be whitespace only."""
        with self.assertRaises(ValueError):
            ProductionOrder(orderNumber="   ")

    # --------------------- Status Transition Tests ---------------------

    def test_valid_status_transition_to_in_progress(self):
        """Test valid transition from PLANNED to IN_PROGRESS."""
        self.order.status = ProductionOrder.IN_PROGRESS
        self.assertEqual(self.order.status, ProductionOrder.IN_PROGRESS)

    def test_valid_status_transition_to_completed(self):
        """Test valid transition from IN_PROGRESS to COMPLETED."""
        self.order.status = ProductionOrder.IN_PROGRESS
        self.order.status = ProductionOrder.COMPLETED
        self.assertEqual(self.order.status, ProductionOrder.COMPLETED)

    def test_invalid_status_transition_from_completed(self):
        """Test that COMPLETED is a final state."""
        self.order.status = ProductionOrder.IN_PROGRESS
        self.order.status = ProductionOrder.COMPLETED

        with self.assertRaises(ValueError):
            self.order.status = ProductionOrder.PLANNED

    def test_invalid_status_transition_from_cancelled(self):
        """Test that CANCELLED is a final state."""
        self.order.status = ProductionOrder.CANCELLED

        with self.assertRaises(ValueError):
            self.order.status = ProductionOrder.PLANNED

    def test_invalid_direct_transition_to_completed(self):
        """Test that cannot transition directly from PLANNED to COMPLETED."""
        with self.assertRaises(ValueError):
            self.order.status = ProductionOrder.COMPLETED

    # --------------------- Line Management Tests ---------------------

    def test_add_line(self):
        """Test adding a line to the order."""
        index = self.order.addLine(self.line1)

        self.assertEqual(index, 0)
        self.assertIn(self.line1, self.order.lines)
        self.assertEqual(len(self.order.lines), 1)

    def test_add_multiple_lines(self):
        """Test adding multiple lines."""
        self.order.addLine(self.line1)
        self.order.addLine(self.line2)

        self.assertEqual(len(self.order.lines), 2)
        self.assertIn(self.line1, self.order.lines)
        self.assertIn(self.line2, self.order.lines)

    def test_cannot_add_duplicate_line(self):
        """Test that duplicate lines are not added."""
        self.order.addLine(self.line1)
        self.order.addLine(self.line1)  # Try adding same line again

        self.assertEqual(len(self.order.lines), 1)

    def test_cannot_add_invalid_line(self):
        """Test that adding a non-ProductionOrderLine raises ValueError."""
        with self.assertRaises(ValueError):
            self.order.addLine("Invalid Line")

    def test_remove_line_by_index(self):
        """Test removing a line by index."""
        self.order.addLine(self.line1)
        self.order.addLine(self.line2)

        self.order.removeLine(0)

        self.assertEqual(len(self.order.lines), 1)
        self.assertNotIn(self.line1, self.order.lines)
        self.assertIn(self.line2, self.order.lines)

    def test_remove_line_invalid_index(self):
        """Test that removing with invalid index raises IndexError."""
        with self.assertRaises(IndexError):
            self.order.removeLine(0)

        self.order.addLine(self.line1)

        with self.assertRaises(IndexError):
            self.order.removeLine(5)

    def test_get_line_by_product_code(self):
        """Test finding a line by product code."""
        self.order.addLine(self.line1)
        self.order.addLine(self.line2)

        found = self.order.getLineByProductCode("PROD-B")
        self.assertEqual(found, self.line2)

    def test_get_line_by_product_code_not_found(self):
        """Test finding a non-existent product code returns None."""
        self.order.addLine(self.line1)

        found = self.order.getLineByProductCode("NONEXISTENT")
        self.assertIsNone(found)

    def test_lines_returns_immutable_tuple(self):
        """Test that lines property returns a tuple (immutable)."""
        self.order.addLine(self.line1)

        lines = self.order.lines
        self.assertIsInstance(lines, tuple)


if __name__ == "__main__":
    unittest.main()
