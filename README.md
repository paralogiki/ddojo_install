# Display Dojo's Linux Device client installer
Install via
```
$ curl -o- https://www.displaydojo.com/client/v1/install | bash
```
```
$ wget -qO- https://www.displaydojo.com/client/v1/install | bash
```
Older machines with outdated root certificates:
```
$ wget -O- --no-check-certificate https://www.displaydojo.com/client/v1/install | bash
```
