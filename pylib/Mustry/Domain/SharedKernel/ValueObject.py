# ---------------------------------------------------------------------
#
# Mustry.Domain.SharedKernel.ValueObject
# January 2026
#
# ---------------------------------------------------------------------

from abc import ABCMeta, abstractmethod


class ValueObject(object):
    __metaclass__ = ABCMeta

    def __init__(self):
        pass

    @abstractmethod
    def getEqualityComponents(self):
        """
        Must return an iterable of attributes required for equality comparison.
        Derived classes must implement this method.
        """
        raise NotImplementedError

    def __str__(self):
        return str(vars(self))

    def __repr__(self):
        cls_name = self.__class__.__name__
        attrs = ", ".join("%s=%r" % (k, v) for k, v in vars(self).items())
        return "%s(%s)" % (cls_name, attrs)

    def __eq__(self, other):
        if not isinstance(other, ValueObject):
            return NotImplemented
        t1 = tuple(self.getEqualityComponents())
        t2 = tuple(other.getEqualityComponents())
        return t1 == t2

    def __ne__(self, other):
        return not self.__eq__(other)


# ---------------------------------------------------------------------
# EOF
