# ---------------------------------------------------------------------
#
# Mustry.Domain.Production.ProductionOrderAggregate.ProductionOrderLine
# January 2026
#
# ---------------------------------------------------------------------

from Mustry.Domain.SharedKernel import Entity
from Mustry.Domain.SharedKernel.Invariants import (
    CannotBeNone,
    CannotBeNoneOrWhitespace,
    MustBePositive
)


class ProductionOrderLine(Entity):

    def __init__(self, id_=None, lineNo=None, productCode=None, quantity=None):
        super(ProductionOrderLine, self).__init__()

        if id_:
            self.id_ = id_

        self.lineNo = lineNo
        self.productCode = productCode
        self.quantity = quantity
        self._completed = False

    @property
    def lineNo(self):
        return self._lineNo

    @lineNo.setter
    @CannotBeNone
    @MustBePositive
    def lineNo(self, value):
        self._lineNo = value

    @property
    def productCode(self):
        return self._productCode

    @productCode.setter
    @CannotBeNoneOrWhitespace
    def productCode(self, value):
        self._productCode = value

    @property
    def quantity(self):
        return self._quantity

    @quantity.setter
    @CannotBeNone
    @MustBePositive
    def quantity(self, value):
        self._quantity = value

    @property
    def completed(self):
        return self._completed

    @completed.setter
    def completed(self, value):
        self._completed = bool(value)

    def markCompleted(self):
        """Mark this line as completed."""
        self._completed = True

    def markIncomplete(self):
        """Mark this line as incomplete."""
        self._completed = False


# ---------------------------------------------------------------------
# EOF
