def testAMQP():
	from com.rabbitmq.client import ConnectionFactory
	factory = ConnectionFactory()
	# Use logger instead of system.perspective.print (which requires session context)
	logger = system.util.getLogger("testAMQP")
	logger.info("AMQP Client loaded! Class: " + factory.getClass().getName())
	return "AMQP Client loaded successfully: " + factory.getClass().getName()