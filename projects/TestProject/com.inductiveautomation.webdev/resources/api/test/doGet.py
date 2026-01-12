def doGet(request, session):
	results = test.all.runTests()
	return {'json': {'results': results}}
