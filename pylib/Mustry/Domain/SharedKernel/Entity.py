# ---------------------------------------------------------------------
#
# Mustry.Domain.SharedKernel.Entity
# January 2026
#
# ---------------------------------------------------------------------

import uuid
from abc import ABCMeta


class Entity(object):
    __metaclass__ = ABCMeta

    def __init__(self):
        super(Entity, self).__init__()
        self._id = None

    @property
    def id_(self):
        return self._id

    @id_.setter
    def id_(self, value):
        if not value:
            raise ValueError("Invalid ID: '%r'." % (value))
        elif isinstance(value, uuid.UUID):
            self._id = str(value)
        else:
            self._id = value

    def __repr__(self):
        cls_name = self.__class__.__name__
        attrs = ", ".join("%s=%r" % (k, v) for k, v in vars(self).items())
        return "%s(%s)" % (cls_name, attrs)


# ---------------------------------------------------------------------
# EOF
