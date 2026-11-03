
# some quick developer commands 

## list servers/services 
detecting servers running

### detecting who is running servers,

```
lsof -nP -iTCP:8090 -sTCP:LISTEN
```

### list all servers running based on programming languages

```
lsof -nP -iTCP -sTCP:LISTEN | grep -iE "dart|python|flutter" 
```

## Terminal Command to list all usb hub and connected devices 

For a more readable version with names, speeds and power use:


```
system_profiler SPUSBDataType
```
On newer macOS versions this may print nothing. Then use this instead:

```
system_profiler SPUSBHostDataType
```
The same information is in System Information, under USB in the sidebar.