import traceback
import functools
from java.lang import Throwable

_logger = system.util.getLogger("RNR.ApiEventsLogger")

def gatewayEventHandler(func):
	"""
	Decorator to handle logging, timing, and error handling for incoming api calls.
	This ensures that the function is properly logged and timed, with errors caught and logged.
	
	Args:
		func (function): The function to wrap with gateway event handling.

	Returns:
		wrapped function
	"""
	@functools.wraps(func)
	def wrapper(*args, **kwargs):
		start = system.date.toMillis(system.date.now())
		_logger.debug("Starting Api Call: {}".format(func.__name__))
		
		try:
			# Call the original function
			result = func(*args, **kwargs)
		except Throwable as t:
			# Handle Java exceptions (Throwable)
			_logger.error("Unhandled Java exception in Api Call: {}\n{}".format(
				func.__name__, traceback.format_exc()))
			raise  # Re-raise to ensure proper handling
		except Exception as e:
			# Handle Python exceptions
			_logger.error("Unhandled Python exception in Api Call: {}\n{}".format(
				func.__name__, traceback.format_exc()))
			raise  # Re-raise to ensure proper handling
		except:
			# Handle any unexpected exceptions
			_logger.error("Unknown error in Api Call: {}\n{}".format(
				func.__name__, traceback.format_exc()))
			raise  # Re-raise to ensure proper handling
		finally:
			end = system.date.toMillis(system.date.now())
			_logger.debug("Api Call {} finished in {} ms.".format(
				func.__name__, str(end - start)))

		return result

	return wrapper