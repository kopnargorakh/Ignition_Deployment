# ---------------------------------------------------------------------
#
# Mustry.Domain.SharedKernel.AggregateRoot
# January 2026
#
# ---------------------------------------------------------------------

from abc import ABCMeta
from Mustry.Domain.SharedKernel.Entity import Entity


class AggregateRoot(Entity):
    __metaclass__ = ABCMeta

    def __init__(self):
        super(AggregateRoot, self).__init__()


# ---------------------------------------------------------------------
# EOF
