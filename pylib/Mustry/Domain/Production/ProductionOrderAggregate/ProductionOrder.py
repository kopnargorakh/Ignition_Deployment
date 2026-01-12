# ---------------------------------------------------------------------
#
# Mustry.Domain.Production.ProductionOrderAggregate.ProductionOrder
# January 2026
#
# ---------------------------------------------------------------------

from Mustry.Domain.SharedKernel import AggregateRoot
from Mustry.Domain.SharedKernel.Invariants import CannotBeNoneOrWhitespace

from .ProductionOrderLine import ProductionOrderLine


class ProductionOrder(AggregateRoot):
    # Status constants
    PLANNED = "PLANNED"
    IN_PROGRESS = "IN_PROGRESS"
    COMPLETED = "COMPLETED"
    CANCELLED = "CANCELLED"

    # Allowed status transitions
    _ALLOWED_TRANSITIONS = {
        PLANNED: {IN_PROGRESS, CANCELLED},
        IN_PROGRESS: {COMPLETED, CANCELLED},
        COMPLETED: set(),
        CANCELLED: set(),
    }

    def __init__(self, id_=None, orderNumber=None, description=None, status=None):
        super(ProductionOrder, self).__init__()

        if id_:
            self.id_ = id_

        self.orderNumber = orderNumber
        self.description = description
        self._status = status or self.PLANNED
        self._lines = []

    @property
    def orderNumber(self):
        return self._orderNumber

    @orderNumber.setter
    @CannotBeNoneOrWhitespace
    def orderNumber(self, value):
        self._orderNumber = value

    @property
    def description(self):
        return self._description

    @description.setter
    def description(self, value):
        self._description = value

    @property
    def status(self):
        return self._status

    @status.setter
    def status(self, newStatus):
        if newStatus not in self._ALLOWED_TRANSITIONS:
            raise ValueError("Invalid status: '{}'.".format(newStatus))

        if newStatus not in self._ALLOWED_TRANSITIONS[self._status]:
            raise ValueError(
                "Invalid transition: {} -> {}.".format(self._status, newStatus)
            )

        self._status = newStatus

    @property
    def lines(self):
        """Returns lines as an immutable tuple."""
        return tuple(self._lines)

    def addLine(self, line):
        """Add a production order line."""
        if not isinstance(line, ProductionOrderLine):
            raise ValueError(
                "Must be an instance of {}.".format(ProductionOrderLine.__name__)
            )

        if line not in self._lines:
            self._lines.append(line)

        return len(self._lines) - 1

    def removeLine(self, index):
        """Remove a production order line by index."""
        if index < 0 or index > len(self._lines) - 1:
            raise IndexError("Invalid index: {}.".format(index))

        del self._lines[index]

    def getLineByProductCode(self, productCode):
        """Find a line by product code."""
        for line in self._lines:
            if line.productCode == productCode:
                return line
        return None


# ---------------------------------------------------------------------
# EOF
