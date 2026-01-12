# ---------------------------------------------------------------------
#
# Mustry.Domain.SharedKernel.Invariants
# January 2026
#
# ---------------------------------------------------------------------


class CannotBeNone(object):
    """Decorator that raises ValueError if property value is None."""

    def __init__(self, func):
        self.func = func
        # Propagate __name__ for stacked decorators
        self.__name__ = getattr(func, '__name__', 'unknown')

    def __call__(self, obj, value):
        if value is None:
            raise ValueError("'{}.{}' cannot be None.".format(
                obj.__class__.__name__,
                self.__name__
            ))
        return self.func(obj, value)


class CannotBeNoneOrWhitespace(object):
    """Decorator that raises ValueError if property value is None or whitespace."""

    def __init__(self, func):
        self.func = func
        self.__name__ = getattr(func, '__name__', 'unknown')

    def __call__(self, obj, value):
        if value is None:
            raise ValueError("'{}.{}' cannot be None.".format(
                obj.__class__.__name__,
                self.__name__
            ))

        if isinstance(value, (str, unicode)) and value.strip() == "":
            raise ValueError("'{}.{}' cannot consist of only whitespace.".format(
                obj.__class__.__name__,
                self.__name__
            ))

        return self.func(obj, value)


class MustBePositive(object):
    """Decorator that raises ValueError if property value is not positive."""

    def __init__(self, func):
        self.func = func
        self.__name__ = getattr(func, '__name__', 'unknown')

    def __call__(self, obj, value):
        if value is not None and value <= 0:
            raise ValueError("'{}.{}' must be a positive number.".format(
                obj.__class__.__name__,
                self.__name__
            ))
        return self.func(obj, value)


# ---------------------------------------------------------------------
# EOF
