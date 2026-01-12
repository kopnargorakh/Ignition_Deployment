def runTests():
	"""Run pylib tests from Script Console"""
	from Mustry.Domain.SharedKernel.Entity import Entity
	from Mustry.Domain.SharedKernel.AggregateRoot import AggregateRoot
	from Mustry.Domain.SharedKernel.ValueObject import ValueObject
	from Mustry.Domain.Production.ProductionOrderAggregate.ProductionOrder import ProductionOrder
	from Mustry.Domain.Production.ProductionOrderAggregate.ProductionOrderLine import ProductionOrderLine

	logger = system.util.getLogger("pylib-test")
	results = []

	# Test 1: Create ProductionOrder
	try:
		order = ProductionOrder(1, "ORD-001", "Test Order")
		assert order.orderNumber == "ORD-001"
		assert order.description == "Test Order"
		results.append("OK: ProductionOrder creation")
	except Exception as e:
		results.append("FAIL: ProductionOrder creation - " + str(e))

	# Test 2: Add line to order
	try:
		order = ProductionOrder(1, "ORD-002", "Test Order 2")
		line = ProductionOrderLine(1, 1, "PROD-A", 100)
		order.addLine(line)
		assert len(order.lines) == 1
		assert order.lines[0].productCode == "PROD-A"
		results.append("OK: ProductionOrderLine add")
	except Exception as e:
		results.append("FAIL: ProductionOrderLine add - " + str(e))

	# Log and return results
	for r in results:
		logger.info(r)

	return "\n".join(results)
