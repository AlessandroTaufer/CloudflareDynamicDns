# CloudflareDynamicDns
A simple tool to automatically update a cloudflare dns record when your ip changes

## Usage
Create a json config file containing the cloudflare auth credentials. You can [see their docs here](https://developers.cloudflare.com/fundamentals/setup/find-account-and-zone-ids/)
```
    {
      "zone_id": "",
      "account_id": "",
      "token": ""
    }
```


And run the script
```
    updateDns.sh record.mydomain.com /path/to/config.json
```

You can also set a cronjob for it
```
    */20 * * * * bash /home/user/updateDns.sh record.mydomain.com /path/to/config.json 2>&1 | logger -t CloudflareDynamicDns
```