# Belimo Energy Valve DSLink

This DSLink will connect with the Belimo Energy Valve REST API.

Upon adding a connection, the link will query all current datapoints and populate a 
Node tree based on the results. To limit throttling the connection, the link will
only send one request at a time, batching queries whenever possible.
