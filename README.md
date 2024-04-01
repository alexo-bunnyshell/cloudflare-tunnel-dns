# Cloudflare Tunnel DNS Record Creation Script

This project contains a bash script for creating DNS records in Cloudflare and pointing to a specified Cloudflare Tunnel.
The script parses the Bunnyshell env definition file (passed in as $COMPONENTS) to extract the list or DNS records to be created.
Next, the script interacts with the Cloudflare API to create DNS records.

## Prerequisites

- Bash
- jq
- curl

## Environment Variables

The script requires the following environment variables:

- `COMPONENTS`: The Bunnyshell yaml env configuration, generated like this:  `COMPONENTS: '{{ component.name}}|{{ components|json_encode }}'` .
- `CF_ACCOUNT_ID`: Your Cloudflare account ID.
- `CF_TUNNEL_ID`: The ID of the Cloudflare tunnel.
- `CF_ZONE_ID`: The ID of the Cloudflare zone.
- one of two ways of authentication:
  - `CF_API_KEY` and `CF_EMAIL`: Your (Global) Cloudflare API key.
  - of `CF_API_TOKEN`: a CF API token with necessary permissions: read account settings, read Tunnel settings and edit zone.
  
## Usage

To run the script, simply execute the `create_records.sh` file in your terminal/pipeline:

```bash
./create_records.sh
```

The script will print out the DNS records that need to be created, retrieve the initial settings from Cloudflare, and then create a record for each URL in the list. If a URL matches the pattern `bunnyenv.com`, it will be skipped.

## License

This project is licensed under the MIT License - see the LICENSE.md file for details.
