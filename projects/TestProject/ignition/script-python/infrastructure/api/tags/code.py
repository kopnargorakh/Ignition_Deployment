import json

logger = system.util.getLogger("RNR.api.TagActionsLogger")

def _res(request, payload, code=200):
	"""Send a JSON response with a given HTTP status code."""
	response = request['servletResponse']
	response.setStatus(code)
	response.setContentType("application/json")
	response.getWriter().write(json.dumps(payload))
	return None

def _errorResponse(request, message, code=400):
	"""Send an error message as JSON with a given HTTP error code."""
	response = request['servletResponse']
	response.setStatus(code)
	response.setContentType("application/json")
	response.getWriter().write(json.dumps({'error': message}))
	return None

def _validatePaths(request, tagPaths):
	"""
	Validate that all tag paths exist and follow the naming rule.
	Raises an error response if any path is invalid or missing.
	"""
	if not tagPaths or len(tagPaths) == 0:
		return _errorResponse(request, "No tag paths provided for validation.", 400)
	
	# Validate path structure (must contain RR_UNS after provider)
	for path in tagPaths:
		# Remove brackets and split to check provider structure
		if 'RR_UNS' not in path:
			return _errorResponse(
				request,
				"Invalid path '{}'. All tag paths must start with 'RR_UNS' after the provider.".format(path),
				400
			)
	
	# Check existence using system.tag.exists
	missing = [p for p in tagPaths if not system.tag.exists(p)]
	if len(missing) > 0:
		return _errorResponse(
			request,
			"The following tags do not exist: {}".format(", ".join(missing)),
			400
		)
	
	return True  # All checks passed


@infrastructure.api.decorators.gatewayEventHandler
def readTags(request, session):
	try:
		param = request['params'].get('tag_paths')
		if not param:
			return _errorResponse(request, 'Missing parameter: tag_paths', 400)

		tagPaths = [p.strip() for p in param.split(',')]
		results = common.tags.readTags(tagPaths)

		return _res(request, {'results': results}, 200)

	except Exception, e:
		logger.error("Error reading tags: {}".format(e))
		return _errorResponse(request, str(e), 500)


@infrastructure.api.decorators.gatewayEventHandler
def writeTags(request, session):
	try:
		data = request.get("data")
		if not data or 'tags' not in data:
			return _errorResponse(request, 'Missing parameter: tags', 400)

		writeData = data['tags']
		if not isinstance(writeData, list) or len(writeData) == 0:
			return _errorResponse(request, 'Empty or invalid tags list', 400)

		tagPaths = [t['path'] for t in writeData if 'path' in t and 'value' in t]
		values = [t['value'] for t in writeData if 'path' in t and 'value' in t]

		if len(tagPaths) == 0:
			return _errorResponse(request, 'No valid tag path/value pairs found', 400)

		# ✅ Validate all paths before writing
		checkResult = _validatePaths(request, tagPaths)
		if checkResult != True:
			return checkResult  # Returns the error response if validation failed

		# ✅ Perform the write
		results = common.tags.writeTags(tagPaths, values)

		# ✅ Format the response
		responseData = []
		for i in range(len(tagPaths)):
			responseData.append({
				'path': unicode(tagPaths[i]),
				'value': str(values[i]),
				'result': str(results[i])
			})

		return _res(request, {'results': responseData}, 200)

	except Exception, e:
		logger.error("Error writing tags: {}".format(e))
		return _errorResponse(request, str(e), 500)