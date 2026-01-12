def runTests():
	"""Run AMQP tests from Script Console"""
	from com.rabbitmq.client import ConnectionFactory

	logger = system.util.getLogger("amqp-test")
	results = []

	# Test 1: ConnectionFactory
	try:
		factory = ConnectionFactory()
		results.append("OK: ConnectionFactory - " + factory.getClass().getName())
	except Exception as e:
		results.append("FAIL: ConnectionFactory - " + str(e))

	# Log and return results
	for r in results:
		logger.info(r)

	return "\n".join(results)
