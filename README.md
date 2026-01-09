# A starting place for getting Trellis sites deployed to SpinupWP

This is based on the excellent writeup by [intelligence](https://intermissionstudio.notion.site/Use-Trellis-for-deployments-on-SpinupWP-2d6fd7dcc1ed4a04b829984eb9ba59a0).

## Prerequisites

- [SpinupWP account](https://spinupwp.com/)
- [Trellis Installed](https://roots.io/trellis/docs/installation/)

## Setup

1. Clone this repository
   '''
   git clone https://github.com/nicbovee/trellis-spinupwp.git --depth 1
   cd trellis-spinupwp
   '''
2. Run the initialization script to configure your Trellis setup
3. Commit your changes to the repository.
4. Run `trellis deploy production` to deploy your site to production.

## Initialization Script

The `init.sh` script automates the configuration of your Trellis setup for SpinupWP deployments. It will:

- Prompt you for all necessary configuration variables
- Generate secure cryptographic salts and keys for WordPress
- Update vault.yml files with your credentials
- Create and encrypt vault files
- Configure hosts files with your server IPs
- Update wordpress_sites.yml files with your domain configuration
- Set up git repository and branch information

### Usage

Run the initialization script from the project root:

```bash
./init.sh
```

### What You'll Be Asked

The script will prompt you for the following information:

#### Production Environment

- Site domain (e.g., example.com)
- Alternative domains (comma-separated, e.g., www.example.com,example.org)
- SPINUP_SITE_DIRECTORY
- WordPress admin email
- SPINUP_SSH_USER
- SPINUP_HOST_IP
- SPINUP_DB_USER
- SPINUP_DB_NAME
- SPINUP_DB_PASSWORD
- Git repository URL (e.g., git@github.com:user/repo.git)
- Git branch (defaults to "main")

#### Staging Environment (Optional)

If you choose to set up a staging environment, you'll be asked for the same information with staging-specific values:

- Staging site domain
- Staging alternative domains
- SPINUP_STAGING_SITE_DIRECTORY
- Staging WordPress admin email
- SPINUP_STAGING_SSH_USER
- SPINUP_STAGING_HOST_IP
- SPINUP_STAGING_DB_USER
- SPINUP_STAGING_DB_NAME
- SPINUP_STAGING_DB_PASSWORD
- Staging Git repository URL
- Staging Git branch (defaults to "master")

### What the Script Does

1. **Generates Secure Credentials**: Creates cryptographically secure passwords, salts, and keys using OpenSSL
2. **Updates Vault Files**: Replaces placeholder values in `group_vars/*/vault.yml` files
3. **Creates Vault Passphrase**: Generates a secure `.vault_pass` file in the trellis directory
4. **Encrypts Vault Files**: Runs `trellis vault encrypt` to encrypt all vault files
5. **Updates Hosts Files**: Configures `hosts/production` and `hosts/staging` with your server IPs
6. **Configures WordPress Sites**: Updates `wordpress_sites.yml` files with your domain configuration (uses `.test` extension for development)
7. **Sets Git Configuration**: Updates repository and branch information for each environment

### Important Notes

- The `.vault_pass` file is created in the `trellis/` directory - keep this secure and never commit it to version control
- Development environment domains are automatically converted to use `.test` extension (e.g., `example.com` becomes `example.test`)
- All vault files are encrypted after configuration
- The script can be run multiple times - it will decrypt existing vault files before updating them
