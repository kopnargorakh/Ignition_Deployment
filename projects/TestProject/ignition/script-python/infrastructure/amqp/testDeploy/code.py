

def testIfLibraryExists():
	from com.rabbitmq.client import ConnectionFactory
	factory = ConnectionFactory()
	system.perspective.print("AMQP Client loaded! Class:", factory.getClass().getName())