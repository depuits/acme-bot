# acme-bot

An SSL certificate auto-renewal and deployment bot running in a Docker container, based on acme.sh.

## Why do we need acme-bot?

[acme.sh](https://github.com/acmesh-official/acme.sh) is an excellent ACME protocol client that supports various DNS APIs and web servers, and can automatically apply for and renew SSL certificates. However, while acme.sh provides an official Docker image, this image cannot automatically update and deploy certificates based on configuration information.

acme-bot is a secondary wrapper based on the official acme.sh Docker image. It can configure acme.sh via environment variables, telling acme.sh your domain name and DNS API information. acme-bot will automatically apply for and renew certificates and automatically deploy certificates to the specified services. Therefore, it is particularly suitable for running in a Docker container as a standalone certificate management bot.

## How to use acme-bot?

Using acme-bot is very simple, requiring only a few environment variables. Here's an example of using acme-bot:

```bash
docker run -d \
--name acme-bot \
-e EMAIL="hello@example.com" \
-e DOMAINS="dns_ali:example.com" \
-e Ali_Key="your_ali_key" \
-e Ali_Secret="your_ali_secret" \
-v $PWD/acme:/acme.sh \
depuits/acme-bot
```

You can also use the ghcr.io image `ghcr.io/depuits/acme-bot`.

I've also provided a `[docker-compose.yml](./docker-compose.yml)` file, which you can use directly with `docker-compose up -d` to start acme-bot. Of course, you'll need to modify the environment variables in the `docker-compose.yml` file.

## Environment Variables

acme-bot supports the following environment variables:

- `EMAIL`: (Required) Your email address, used to register an acme.sh account.

- `DOMAINS`: (Required) Your domain name and DNS API information, in the format `dns_api:domain1,*.domain1,...[/deploy_hook]`. `dns_api` is the name of your DNS API; for a complete list of supported APIs, please refer to the [acme.sh documentation](https://github.com/acmesh-official/acme.sh/wiki/dnsapi). `domain1,*.domain1,...` is a list of your domain names and wildcard domains, separated by commas. `/deploy_hook` is optional and specifies the deployment method for certificates after release/renewal; for a complete list of supported APIs, please refer to the [acme.sh documentation](https://github.com/acmesh-official/acme.sh/wiki/deployhooks). - `CA`: (Optional) The ACME server for acme.sh. The default is zerossl. You can specify other ACME servers; please refer to the [acme.sh documentation](https://github.com/acmesh-official/acme.sh/wiki/Server) for a complete list of supported servers.

- `NOTIFY`: (Optional) The notification method `notify-hook`. You can specify various notification methods; please refer to the [acme.sh documentation](https://github.com/acmesh-official/acme.sh/wiki/notify) for a complete list of supported methods. Multiple `notify-hook`s are separated by commas.

⚠️Note: After specifying `dns_api`, `deploy_hook`, and `notify-hook` in the above configuration information, the corresponding environment variables need to be configured. Please refer to the [acme.sh documentation](https://github.com/acmesh-official/acme.sh/wiki) for a complete list of supported environment variables.
