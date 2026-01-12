def runTests():
	"""Run all tests after deploy"""
	results = []

	# Run pylib tests
	try:
		pylibResults = test.pylib.runTests()
		results.append("=== PYLIB TESTS ===")
		results.append(pylibResults)
	except Exception as e:
		results.append("=== PYLIB TESTS ===")
		results.append("FAIL: " + str(e))

	# Run AMQP tests
	try:
		amqpResults = test.amqp.runTests()
		results.append("=== AMQP TESTS ===")
		results.append(amqpResults)
	except Exception as e:
		results.append("=== AMQP TESTS ===")
		results.append("FAIL: " + str(e))

	return "\n".join(results)
