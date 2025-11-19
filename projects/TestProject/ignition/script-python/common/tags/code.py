

def readTags(tagPaths):
	"""
	Read multiple tags in Ignition using system.tag.readBlocking().
	
	Args:
		tagPaths (list): List of tag paths to read
	
	Returns:
		dict: Dictionary of {tagPath: value}
	"""
	
	# Perform a blocking read on all tag paths
	results = system.tag.readBlocking(tagPaths)
	
	# Create a dictionary to store results
	values = {}
	
	# Loop through each result and store in dictionary
	for i in range(len(tagPaths)):
		values[tagPaths[i]] = results[i].value
	
	return values

def writeTags(tagPaths, values):
	"""
	Write multiple tags in Ignition using system.tag.writeBlocking().
	
	Args:
		tagPaths (list): List of tag paths to write
		values (list): List of values to write, matching order of tagPaths
	
	Returns:
		list: List of qualified write results
	"""
	
	# Safety check: tagPaths and values must be same length
	if len(tagPaths) != len(values):
		raise Exception("Tag paths and values lists must have the same length.")
	
	# Perform the write operation
	results = system.tag.writeBlocking(tagPaths, values)
	
	# Optionally log result or return for inspection
	return results