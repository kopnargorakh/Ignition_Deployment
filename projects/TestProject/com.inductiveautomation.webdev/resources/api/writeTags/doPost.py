def doPost(request, session):
	return infrastructure.api.tags.writeTags(request, session)