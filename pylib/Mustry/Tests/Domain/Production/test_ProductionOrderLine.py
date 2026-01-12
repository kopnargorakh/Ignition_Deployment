# -*- coding: utf-8 -*-
import unittest

from Mustry.Domain.Production.ProductionOrderAggregate import ProductionOrderLine


class TestProductionOrderLine(unittest.TestCase):

    def setUp(self):
        """Set up reusable test data."""
        self.line = ProductionOrderLine(
            id_=1,
            lineNo=1,
            productCode="PROD-A",
            quantity=100
        )

    # --------------------- Initialization Tests ---------------------

    def test_initialization_defaults(self):
        """Test that a ProductionOrderLine initializes correctly."""
        self.assertEqual(self.line.id_, 1)
        self.assertEqual(self.line.lineNo, 1)
        self.assertEqual(self.line.productCode, "PROD-A")
        self.assertEqual(self.line.quantity, 100)
        self.assertFalse(self.line.completed)

    def test_initialization_without_id(self):
        """Test initialization without providing an id."""
        line = ProductionOrderLine(lineNo=1, productCode="TEST", quantity=50)
        self.assertIsNone(line.id_)

    # --------------------- Line Number Validation Tests ---------------------

    def test_line_no_cannot_be_none(self):
        """Test that line number cannot be None."""
        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=None, productCode="TEST", quantity=10)

    def test_line_no_must_be_positive(self):
        """Test that line number must be positive."""
        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=0, productCode="TEST", quantity=10)

        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=-1, productCode="TEST", quantity=10)

    # --------------------- Product Code Validation Tests ---------------------

    def test_product_code_cannot_be_none(self):
        """Test that product code cannot be None."""
        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=1, productCode=None, quantity=10)

    def test_product_code_cannot_be_whitespace(self):
        """Test that product code cannot be whitespace only."""
        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=1, productCode="   ", quantity=10)

    # --------------------- Quantity Validation Tests ---------------------

    def test_quantity_cannot_be_none(self):
        """Test that quantity cannot be None."""
        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=1, productCode="TEST", quantity=None)

    def test_quantity_must_be_positive(self):
        """Test that quantity must be positive."""
        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=1, productCode="TEST", quantity=0)

        with self.assertRaises(ValueError):
            ProductionOrderLine(lineNo=1, productCode="TEST", quantity=-5)

    # --------------------- Completed Status Tests ---------------------

    def test_mark_completed(self):
        """Test marking a line as completed."""
        self.assertFalse(self.line.completed)

        self.line.markCompleted()

        self.assertTrue(self.line.completed)

    def test_mark_incomplete(self):
        """Test marking a line as incomplete."""
        self.line.markCompleted()
        self.assertTrue(self.line.completed)

        self.line.markIncomplete()

        self.assertFalse(self.line.completed)

    def test_completed_setter(self):
        """Test setting completed via property."""
        self.line.completed = True
        self.assertTrue(self.line.completed)

        self.line.completed = False
        self.assertFalse(self.line.completed)

    def test_completed_setter_coerces_to_bool(self):
        """Test that completed setter coerces values to boolean."""
        self.line.completed = 1
        self.assertTrue(self.line.completed)

        self.line.completed = 0
        self.assertFalse(self.line.completed)

        self.line.completed = "yes"
        self.assertTrue(self.line.completed)

    # --------------------- Property Update Tests ---------------------

    def test_update_quantity(self):
        """Test updating quantity after creation."""
        self.line.quantity = 200
        self.assertEqual(self.line.quantity, 200)

    def test_update_product_code(self):
        """Test updating product code after creation."""
        self.line.productCode = "PROD-B"
        self.assertEqual(self.line.productCode, "PROD-B")


if __name__ == "__main__":
    unittest.main()
