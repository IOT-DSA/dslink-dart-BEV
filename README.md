# Belimo Energy Valve DSLink

This DSLink will connect with the Belimo Energy Valve REST API.

Upon adding a connection, the link will query all current datapoints and populate a 
Node tree based on the results. To limit throttling the connection, the link will
only send one request at a time, batching queries whenever possible.

## Connections

A connection is a link to a specified address for a Belimo Energy Valve. A connection
requires a unique identifier name, address in the format: `http://someaddress.com`.
Do not specify the entire path to the api (eg: `/api/v1/datapoints`) as this will be
detected by the link.

You are also required to specify the username and password required to log into the
device. Finally you may supply a refresh interval on how frequently, in seconds, the
device should be polled for the subscribed data.

## Usage

After adding a connection the broker will attempt to estabilish a connection to the
Energy Valve and will populate nodes based on the results. If it is unable to establish
a connection, you can use the `Edit Connection` action on the link to modify the address,
username, password or refresh interval.

If configuration changes have been made to the Energy Valve to specify new Nodes, you can
update the link with the `Refresh Connection` action on the link. Alternatively you may
also `Remove Connection` to remove that connection entirely.

If the configuration of the Belimo Energy Valve supports it, and the login credentials
provided have required access, some values may be updated within the Energy Valve by
selecting the value and using the `@set` action.
