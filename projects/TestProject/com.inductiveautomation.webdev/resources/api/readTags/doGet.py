def doGet(request, session):
	return infrastructure.api.tags.readTags(request, session)