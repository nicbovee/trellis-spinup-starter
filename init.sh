#!/bin/bash

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TRELLIS_DIR="${SCRIPT_DIR}/trellis"

# Function to prompt for input
prompt() {
    local prompt_text="$1"
    local default_value="${2:-}"
    local var_name="$3"
    local is_password="${4:-false}"
    
    if [ -n "$default_value" ]; then
        prompt_text="${prompt_text} [${default_value}]: "
    else
        prompt_text="${prompt_text}: "
    fi
    
    if [ "$is_password" = "true" ]; then
        read -sp "$prompt_text" value
        echo ""
    else
        read -p "$prompt_text" value
    fi
    
    if [ -z "$value" ] && [ -n "$default_value" ]; then
        value="$default_value"
    fi
    
    eval "$var_name='$value'"
}

# Function to generate WordPress salt/key (64 characters)
generate_wordpress_salt() {
    openssl rand -base64 48 | tr -d '\n' | cut -c1-64
}

# Function to generate password (44 characters, secure)
generate_password() {
    openssl rand -base64 32 | tr -d '\n' | cut -c1-44
}

# Function to generate vault passphrase
generate_vault_pass() {
    openssl rand -base64 32 | tr -d '\n'
}

# Function to replace in file
replace_in_file() {
    local file="$1"
    local search="$2"
    local replace="$3"
    
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s|${search}|${replace}|g" "$file"
    else
        # Linux
        sed -i "s|${search}|${replace}|g" "$file"
    fi
}

echo -e "${GREEN}=== Trellis Spinup Initialization Script ===${NC}\n"

# Verify required files exist
echo -e "${GREEN}Verifying required files exist...${NC}"
MISSING_FILES=()

REQUIRED_FILES=(
    "${TRELLIS_DIR}/group_vars/development/vault.yml"
    "${TRELLIS_DIR}/group_vars/production/vault.yml"
    "${TRELLIS_DIR}/group_vars/production/wordpress_sites.yml"
    "${TRELLIS_DIR}/group_vars/production/main.yml"
    "${TRELLIS_DIR}/hosts/production"
    "${TRELLIS_DIR}/group_vars/development/wordpress_sites.yml"
)

for file in "${REQUIRED_FILES[@]}"; do
    if [ ! -f "$file" ]; then
        MISSING_FILES+=("$file")
    fi
done

if [ ${#MISSING_FILES[@]} -gt 0 ]; then
    echo -e "${RED}Error: The following required files are missing:${NC}"
    for file in "${MISSING_FILES[@]}"; do
        echo -e "  ${RED}✗${NC} $file"
    done
    echo ""
    echo -e "${YELLOW}Please ensure you have cloned the complete repository.${NC}"
    echo -e "${YELLOW}If you cloned with --depth 1, try cloning without it to get all files.${NC}"
    exit 1
fi

echo -e "${GREEN}✓ All required files found${NC}\n"

# Prompt for production environment variables
echo -e "${YELLOW}Production Environment Configuration${NC}"
echo "----------------------------------------"

prompt "Site domain (e.g., example.com)" "" "PROD_DOMAIN"
prompt "Alternative domains (comma-separated, e.g., www.example.com,example.org)" "" "PROD_ALT_DOMAINS"
prompt "SPINUP_SITE_DIRECTORY" "" "SPINUP_SITE_DIRECTORY"
prompt "WordPress admin email" "" "PROD_ADMIN_EMAIL"
prompt "SPINUP_SSH_USER" "" "SPINUP_SSH_USER"
prompt "SPINUP_HOST_IP" "" "SPINUP_HOST_IP"
prompt "SPINUP_DB_USER" "" "SPINUP_DB_USER"
prompt "SPINUP_DB_NAME" "" "SPINUP_DB_NAME"
prompt "SPINUP_DB_PASSWORD" "" "SPINUP_DB_PASSWORD" "true"
prompt "Git repository URL (e.g., git@github.com:user/repo.git)" "" "PROD_GIT_REPO"
prompt "Git branch" "main" "PROD_GIT_BRANCH"

echo ""
prompt "Do you need a staging environment? (yes/no)" "no" "NEED_STAGING"

NEED_STAGING=$(echo "$NEED_STAGING" | tr '[:upper:]' '[:lower:]')

STAGING_DOMAIN=""
STAGING_ALT_DOMAINS=""
SPINUP_STAGING_SITE_DIRECTORY=""
STAGING_ADMIN_EMAIL=""
SPINUP_STAGING_SSH_USER=""
SPINUP_STAGING_HOST_IP=""
SPINUP_STAGING_DB_USER=""
SPINUP_STAGING_DB_NAME=""
SPINUP_STAGING_DB_PASSWORD=""
STAGING_GIT_REPO=""
STAGING_GIT_BRANCH=""

if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    echo ""
    echo -e "${YELLOW}Staging Environment Configuration${NC}"
    echo "----------------------------------------"
    
    prompt "Staging site domain (e.g., staging.example.com)" "" "STAGING_DOMAIN"
    prompt "Staging alternative domains (comma-separated)" "" "STAGING_ALT_DOMAINS"
    prompt "SPINUP_STAGING_SITE_DIRECTORY" "" "SPINUP_STAGING_SITE_DIRECTORY"
    prompt "Staging WordPress admin email" "" "STAGING_ADMIN_EMAIL"
    prompt "SPINUP_STAGING_SSH_USER" "" "SPINUP_STAGING_SSH_USER"
    prompt "SPINUP_STAGING_HOST_IP" "" "SPINUP_STAGING_HOST_IP"
    prompt "SPINUP_STAGING_DB_USER" "" "SPINUP_STAGING_DB_USER"
    prompt "SPINUP_STAGING_DB_NAME" "" "SPINUP_STAGING_DB_NAME"
    prompt "SPINUP_STAGING_DB_PASSWORD" "" "SPINUP_STAGING_DB_PASSWORD" "true"
    prompt "Staging Git repository URL (e.g., git@github.com:user/repo.git)" "" "STAGING_GIT_REPO"
    prompt "Staging Git branch" "master" "STAGING_GIT_BRANCH"
fi

echo ""
echo -e "${GREEN}Generating cryptographic salts and keys...${NC}"

# Generate all required salts and keys
PROD_AUTH_KEY=$(generate_wordpress_salt)
PROD_SECURE_AUTH_KEY=$(generate_wordpress_salt)
PROD_LOGGED_IN_KEY=$(generate_wordpress_salt)
PROD_NONCE_KEY=$(generate_wordpress_salt)
PROD_AUTH_SALT=$(generate_wordpress_salt)
PROD_SECURE_AUTH_SALT=$(generate_wordpress_salt)
PROD_LOGGED_IN_SALT=$(generate_wordpress_salt)
PROD_NONCE_SALT=$(generate_wordpress_salt)
PROD_MYSQL_ROOT_PASSWORD=$(generate_password)
PROD_ADMIN_PASSWORD=$(generate_password)

if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    STAGING_AUTH_KEY=$(generate_wordpress_salt)
    STAGING_SECURE_AUTH_KEY=$(generate_wordpress_salt)
    STAGING_LOGGED_IN_KEY=$(generate_wordpress_salt)
    STAGING_NONCE_KEY=$(generate_wordpress_salt)
    STAGING_AUTH_SALT=$(generate_wordpress_salt)
    STAGING_SECURE_AUTH_SALT=$(generate_wordpress_salt)
    STAGING_LOGGED_IN_SALT=$(generate_wordpress_salt)
    STAGING_NONCE_SALT=$(generate_wordpress_salt)
    STAGING_MYSQL_ROOT_PASSWORD=$(generate_password)
    STAGING_ADMIN_PASSWORD=$(generate_password)
    STAGING_USER_PASSWORD=$(generate_password)
    STAGING_USER_SALT=$(generate_wordpress_salt)
fi

# Generate vault passphrase
VAULT_PASS=$(generate_vault_pass)

echo -e "${GREEN}Updating vault.yml files...${NC}"

# Verify trellis directory exists
if [ ! -d "$TRELLIS_DIR" ]; then
    echo -e "${RED}Error: Trellis directory not found at ${TRELLIS_DIR}${NC}"
    echo "Please run this script from the project root directory."
    exit 1
fi

# Decrypt vault files if they're already encrypted (for re-running the script)
cd "$TRELLIS_DIR"
if [ -f ".vault_pass" ]; then
    for vault_file in group_vars/development/vault.yml group_vars/production/vault.yml group_vars/staging/vault.yml; do
        if [ -f "$vault_file" ] && head -n1 "$vault_file" 2>/dev/null | grep -q '\$ANSIBLE_VAULT'; then
            echo -e "${YELLOW}Decrypting ${vault_file} for update...${NC}"
            ansible-vault decrypt "$vault_file" --vault-password-file .vault_pass 2>/dev/null || true
        fi
    done
fi

# Update development vault.yml
DEV_VAULT="${TRELLIS_DIR}/group_vars/development/vault.yml"
if [ -f "$DEV_VAULT" ]; then
    echo -e "  Updating ${DEV_VAULT}..."
    replace_in_file "$DEV_VAULT" "SPINUP_DB_USER" "$SPINUP_DB_USER"
    replace_in_file "$DEV_VAULT" "SPINUP_DB_NAME" "$SPINUP_DB_NAME"
    replace_in_file "$DEV_VAULT" "SPINUP_DB_PASSWORD" "$SPINUP_DB_PASSWORD"
    replace_in_file "$DEV_VAULT" "vault_mysql_root_password: GENERATE_ME" "vault_mysql_root_password: ${PROD_MYSQL_ROOT_PASSWORD}"
    replace_in_file "$DEV_VAULT" "auth_key: GENERATE_ME" "auth_key: ${PROD_AUTH_KEY}"
    replace_in_file "$DEV_VAULT" "secure_auth_key: GENERATE_ME" "secure_auth_key: ${PROD_SECURE_AUTH_KEY}"
    replace_in_file "$DEV_VAULT" "logged_in_key: GENERATE_ME" "logged_in_key: ${PROD_LOGGED_IN_KEY}"
    replace_in_file "$DEV_VAULT" "nonce_key: GENERATE_ME" "nonce_key: ${PROD_NONCE_KEY}"
    replace_in_file "$DEV_VAULT" "auth_salt: GENERATE_ME" "auth_salt: ${PROD_AUTH_SALT}"
    replace_in_file "$DEV_VAULT" "secure_auth_salt: GENERATE_ME" "secure_auth_salt: ${PROD_SECURE_AUTH_SALT}"
    replace_in_file "$DEV_VAULT" "logged_in_salt: GENERATE_ME" "logged_in_salt: ${PROD_LOGGED_IN_SALT}"
    replace_in_file "$DEV_VAULT" "nonce_salt: GENERATE_ME" "nonce_salt: ${PROD_NONCE_SALT}"
    replace_in_file "$DEV_VAULT" "admin_password: GENERATE_ME" "admin_password: ${PROD_ADMIN_PASSWORD}"
else
    echo -e "${YELLOW}  Warning: ${DEV_VAULT} not found, skipping...${NC}"
fi

# Update production vault.yml
PROD_VAULT="${TRELLIS_DIR}/group_vars/production/vault.yml"
if [ -f "$PROD_VAULT" ]; then
    echo -e "  Updating ${PROD_VAULT}..."
    replace_in_file "$PROD_VAULT" "SPINUP_DB_USER" "$SPINUP_DB_USER"
    replace_in_file "$PROD_VAULT" "SPINUP_DB_NAME" "$SPINUP_DB_NAME"
    replace_in_file "$PROD_VAULT" "SPINUP_DB_PASSWORD" "$SPINUP_DB_PASSWORD"
    # Handle empty vault_mysql_root_password line
    if grep -q "^vault_mysql_root_password:$" "$PROD_VAULT"; then
        if [[ "$OSTYPE" == "darwin"* ]]; then
            sed -i '' "s|^vault_mysql_root_password:$|vault_mysql_root_password: ${PROD_MYSQL_ROOT_PASSWORD}|g" "$PROD_VAULT"
        else
            sed -i "s|^vault_mysql_root_password:$|vault_mysql_root_password: ${PROD_MYSQL_ROOT_PASSWORD}|g" "$PROD_VAULT"
        fi
    elif grep -q "^vault_mysql_root_password: GENERATE_ME$" "$PROD_VAULT"; then
        replace_in_file "$PROD_VAULT" "vault_mysql_root_password: GENERATE_ME" "vault_mysql_root_password: ${PROD_MYSQL_ROOT_PASSWORD}"
    fi
    replace_in_file "$PROD_VAULT" "password: GENERATE_ME" "password: ${PROD_ADMIN_PASSWORD}"
    replace_in_file "$PROD_VAULT" "salt: GENERATE_ME" "salt: ${STAGING_USER_SALT:-$(generate_wordpress_salt)}"
    replace_in_file "$PROD_VAULT" "auth_key: GENERATE_ME" "auth_key: ${PROD_AUTH_KEY}"
    replace_in_file "$PROD_VAULT" "secure_auth_key: GENERATE_ME" "secure_auth_key: ${PROD_SECURE_AUTH_KEY}"
    replace_in_file "$PROD_VAULT" "logged_in_key: GENERATE_ME" "logged_in_key: ${PROD_LOGGED_IN_KEY}"
    replace_in_file "$PROD_VAULT" "nonce_key: GENERATE_ME" "nonce_key: ${PROD_NONCE_KEY}"
    replace_in_file "$PROD_VAULT" "auth_salt: GENERATE_ME" "auth_salt: ${PROD_AUTH_SALT}"
    replace_in_file "$PROD_VAULT" "secure_auth_salt: GENERATE_ME" "secure_auth_salt: ${PROD_SECURE_AUTH_SALT}"
    replace_in_file "$PROD_VAULT" "logged_in_salt: GENERATE_ME" "logged_in_salt: ${PROD_LOGGED_IN_SALT}"
    replace_in_file "$PROD_VAULT" "nonce_salt: GENERATE_ME" "nonce_salt: ${PROD_NONCE_SALT}"
    replace_in_file "$PROD_VAULT" "admin_password: GENERATE_ME" "admin_password: ${PROD_ADMIN_PASSWORD}"
else
    echo -e "${YELLOW}  Warning: ${PROD_VAULT} not found, skipping...${NC}"
fi

# Update staging vault.yml if needed
if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    STAGING_VAULT="${TRELLIS_DIR}/group_vars/staging/vault.yml"
    if [ -f "$STAGING_VAULT" ]; then
        echo -e "  Updating ${STAGING_VAULT}..."
        replace_in_file "$STAGING_VAULT" "SPINUP_DB_USER" "$SPINUP_STAGING_DB_USER"
        replace_in_file "$STAGING_VAULT" "SPINUP_DB_NAME" "$SPINUP_STAGING_DB_NAME"
        replace_in_file "$STAGING_VAULT" "SPINUP_DB_PASSWORD" "$SPINUP_STAGING_DB_PASSWORD"
        replace_in_file "$STAGING_VAULT" "vault_mysql_root_password: GENERATE_ME" "vault_mysql_root_password: ${STAGING_MYSQL_ROOT_PASSWORD}"
        replace_in_file "$STAGING_VAULT" "password: GENERATE_ME" "password: ${STAGING_USER_PASSWORD}"
        replace_in_file "$STAGING_VAULT" "salt: GENERATE_ME" "salt: ${STAGING_USER_SALT}"
        replace_in_file "$STAGING_VAULT" "auth_key: GENERATE_ME" "auth_key: ${STAGING_AUTH_KEY}"
        replace_in_file "$STAGING_VAULT" "secure_auth_key: GENERATE_ME" "secure_auth_key: ${STAGING_SECURE_AUTH_KEY}"
        replace_in_file "$STAGING_VAULT" "logged_in_key: GENERATE_ME" "logged_in_key: ${STAGING_LOGGED_IN_KEY}"
        replace_in_file "$STAGING_VAULT" "nonce_key: GENERATE_ME" "nonce_key: ${STAGING_NONCE_KEY}"
        replace_in_file "$STAGING_VAULT" "auth_salt: GENERATE_ME" "auth_salt: ${STAGING_AUTH_SALT}"
        replace_in_file "$STAGING_VAULT" "secure_auth_salt: GENERATE_ME" "secure_auth_salt: ${STAGING_SECURE_AUTH_SALT}"
        replace_in_file "$STAGING_VAULT" "logged_in_salt: GENERATE_ME" "logged_in_salt: ${STAGING_LOGGED_IN_SALT}"
        replace_in_file "$STAGING_VAULT" "nonce_salt: GENERATE_ME" "nonce_salt: ${STAGING_NONCE_SALT}"
        replace_in_file "$STAGING_VAULT" "admin_password: GENERATE_ME" "admin_password: ${STAGING_ADMIN_PASSWORD}"
    else
        echo -e "${YELLOW}  Warning: ${STAGING_VAULT} not found, skipping...${NC}"
    fi
fi

echo -e "${GREEN}Creating .vault_pass file...${NC}"
echo "$VAULT_PASS" > "${TRELLIS_DIR}/.vault_pass"
chmod 600 "${TRELLIS_DIR}/.vault_pass"

echo -e "${GREEN}Encrypting vault files...${NC}"
cd "$TRELLIS_DIR"
trellis vault encrypt

echo -e "${GREEN}Updating hosts files...${NC}"

# Update production hosts file
PROD_HOSTS="${TRELLIS_DIR}/hosts/production"
if [ -f "$PROD_HOSTS" ]; then
    echo -e "  Updating ${PROD_HOSTS}..."
    replace_in_file "$PROD_HOSTS" "SPINUP_HOST_IP" "$SPINUP_HOST_IP"
    replace_in_file "$PROD_HOSTS" "SPINUP_SSH_USER" "$SPINUP_SSH_USER"
else
    echo -e "${YELLOW}  Warning: ${PROD_HOSTS} not found, skipping...${NC}"
fi

# Update staging hosts file if needed
if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    STAGING_HOSTS="${TRELLIS_DIR}/hosts/staging"
    if [ -f "$STAGING_HOSTS" ]; then
        echo -e "  Updating ${STAGING_HOSTS}..."
        replace_in_file "$STAGING_HOSTS" "SPINUP_STAGING_HOST_IP" "$SPINUP_STAGING_HOST_IP"
        replace_in_file "$STAGING_HOSTS" "SPINUP_SSH_USER" "$SPINUP_STAGING_SSH_USER"
    else
        echo -e "${YELLOW}  Warning: ${STAGING_HOSTS} not found, skipping...${NC}"
    fi
fi

echo -e "${GREEN}Updating wordpress_sites.yml files...${NC}"

# Function to update wordpress_sites.yml
update_wordpress_sites() {
    local file="$1"
    local domain="$2"
    local alt_domains="$3"
    local admin_email="$4"
    local use_test="${5:-false}"  # Whether to use .test extension for development
    local git_repo="${6:-}"
    local git_branch="${7:-}"
    
    # Convert domain to .test if needed
    if [ "$use_test" = "true" ]; then
        domain=$(echo "$domain" | sed 's/\.com$/.test/')
        # Also convert alt_domains
        if [ -n "$alt_domains" ]; then
            alt_domains=$(echo "$alt_domains" | sed 's/\.com/.test/g')
        fi
    fi
    
    # Create a temporary Python script to handle the YAML update
    local temp_script=$(mktemp)
    cat > "$temp_script" << PYTHON_EOF
import sys
import re

file_path = sys.argv[1]
domain = sys.argv[2]
alt_domains = sys.argv[3]
admin_email = sys.argv[4]
git_repo = sys.argv[5] if len(sys.argv) > 5 else ''
git_branch = sys.argv[6] if len(sys.argv) > 6 else ''

with open(file_path, 'r') as f:
    content = f.read()

# Replace the site key
content = re.sub(r'trellis-spinupwp\.com:', f'{domain}:', content)

# Parse domains
all_domains = [d.strip() for d in alt_domains.split(',') if d.strip()]
if not all_domains:
    canonical = domain
    redirects = []
else:
    canonical = all_domains[0]
    redirects = all_domains[1:]
    # Add main domain to redirects if it's not the canonical
    if domain != canonical and domain not in redirects:
        redirects.append(domain)

# Update canonical
content = re.sub(r'(\s+canonical:\s*)[^\n]+', f'\\1{canonical}', content)

# Handle redirects section
if redirects:
    # Build redirects YAML (8 spaces for list item content)
    redirects_yaml = 'redirects:\n'
    for r in redirects:
        redirects_yaml += f'          - {r}\n'
    
    # Check if redirects section exists
    if re.search(r'\s+redirects:', content):
        # Replace existing redirects (match redirects: and all following redirect items)
        content = re.sub(r'(\s+redirects:\s*\n)(?:\s+-[^\n]+\n)*', f'\\1{redirects_yaml}', content)
    else:
        # Insert redirects after canonical line
        content = re.sub(r'(\s+- canonical:\s*[^\n]+\n)', f'\\1{redirects_yaml}', content)
else:
    # Remove redirects section if it exists
    content = re.sub(r'\s+redirects:\s*\n(?:\s+-[^\n]+\n)*', '', content)

# Update admin_email
content = re.sub(r'(admin_email:\s*)[^\n]+', f'\\1{admin_email}', content)

# Update git repo if provided
if git_repo:
    if re.search(r'^\s+repo:', content, re.MULTILINE):
        content = re.sub(r'(\s+repo:\s*)[^\n]+', f'\\1{git_repo}', content)
    else:
        # Insert repo after local_path
        content = re.sub(r'(local_path:\s*[^\n]+\n)', f'\\1    repo: {git_repo}\n', content)

# Update git branch if provided
if git_branch:
    if re.search(r'^\s+branch:', content, re.MULTILINE):
        content = re.sub(r'(\s+branch:\s*)[^\n]+', f'\\1{git_branch}', content)
    else:
        # Insert branch after repo (or after local_path if no repo)
        if git_repo:
            content = re.sub(r'(repo:\s*[^\n]+\n)', f'\\1    branch: {git_branch}\n', content)
        else:
            content = re.sub(r'(local_path:\s*[^\n]+\n)', f'\\1    branch: {git_branch}\n', content)

# Fix local_path indentation if it's incorrectly placed inside site_hosts (8 spaces)
# It should be at the same level as site_hosts (4 spaces)
# Pattern: 8 spaces = inside site_hosts list item, should be 4 spaces = same as site_hosts
content = re.sub(r'^(\s{8})local_path:\s*([^\n]+)$', r'    local_path: \2', content, flags=re.MULTILINE)

with open(file_path, 'w') as f:
    f.write(content)
PYTHON_EOF

    python3 "$temp_script" "$file" "$domain" "$alt_domains" "$admin_email" "$git_repo" "$git_branch"
    rm "$temp_script"
}

# Update development wordpress_sites.yml (use .test extension)
DEV_WP_SITES="${TRELLIS_DIR}/group_vars/development/wordpress_sites.yml"
if [ -f "$DEV_WP_SITES" ]; then
    echo -e "  Updating ${DEV_WP_SITES}..."
    update_wordpress_sites "$DEV_WP_SITES" "$PROD_DOMAIN" "$PROD_ALT_DOMAINS" "$PROD_ADMIN_EMAIL" "true" "$PROD_GIT_REPO" "$PROD_GIT_BRANCH"
else
    echo -e "${YELLOW}  Warning: ${DEV_WP_SITES} not found, skipping...${NC}"
fi

# Update production wordpress_sites.yml
PROD_WP_SITES="${TRELLIS_DIR}/group_vars/production/wordpress_sites.yml"
if [ -f "$PROD_WP_SITES" ]; then
    echo -e "  Updating ${PROD_WP_SITES}..."
    update_wordpress_sites "$PROD_WP_SITES" "$PROD_DOMAIN" "$PROD_ALT_DOMAINS" "$PROD_ADMIN_EMAIL" "false" "$PROD_GIT_REPO" "$PROD_GIT_BRANCH"
else
    echo -e "${YELLOW}  Warning: ${PROD_WP_SITES} not found, skipping...${NC}"
fi

# Update staging wordpress_sites.yml if needed
if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    STAGING_WP_SITES="${TRELLIS_DIR}/group_vars/staging/wordpress_sites.yml"
    if [ -f "$STAGING_WP_SITES" ]; then
        echo -e "  Updating ${STAGING_WP_SITES}..."
        update_wordpress_sites "$STAGING_WP_SITES" "$STAGING_DOMAIN" "$STAGING_ALT_DOMAINS" "$STAGING_ADMIN_EMAIL" "false" "$STAGING_GIT_REPO" "$STAGING_GIT_BRANCH"
    else
        echo -e "${YELLOW}  Warning: ${STAGING_WP_SITES} not found, skipping...${NC}"
    fi
fi

echo -e "${GREEN}Updating main.yml files...${NC}"

# Update production main.yml
PROD_MAIN="${TRELLIS_DIR}/group_vars/production/main.yml"
if [ -f "$PROD_MAIN" ]; then
    echo -e "  Updating ${PROD_MAIN}..."
    replace_in_file "$PROD_MAIN" "SPINUP_SITE_DIRECTORY" "$SPINUP_SITE_DIRECTORY"
    replace_in_file "$PROD_MAIN" "SPINUP_SSH_USER" "$SPINUP_SSH_USER"
else
    echo -e "${YELLOW}  Warning: ${PROD_MAIN} not found, skipping...${NC}"
fi

# Update staging main.yml if needed
if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    STAGING_MAIN="${TRELLIS_DIR}/group_vars/staging/main.yml"
    if [ -f "$STAGING_MAIN" ]; then
        echo -e "  Updating ${STAGING_MAIN}..."
        replace_in_file "$STAGING_MAIN" "SPINUP_STAGING_SITE_DIRECTORY" "$SPINUP_STAGING_SITE_DIRECTORY"
        replace_in_file "$STAGING_MAIN" "SPINUP_STAGING_SSH_USER" "$SPINUP_STAGING_SSH_USER"
    else
        echo -e "${YELLOW}  Warning: ${STAGING_MAIN} not found, skipping...${NC}"
    fi
fi

echo ""
echo -e "${GREEN}✓ Initialization complete!${NC}"
echo ""
echo -e "${YELLOW}Summary of updated files:${NC}"

# Summary of what was updated
UPDATED_FILES=()
if [ -f "${TRELLIS_DIR}/group_vars/development/vault.yml" ]; then
    UPDATED_FILES+=("✓ development/vault.yml")
fi
if [ -f "${TRELLIS_DIR}/group_vars/production/vault.yml" ]; then
    UPDATED_FILES+=("✓ production/vault.yml")
fi
if [ -f "${TRELLIS_DIR}/group_vars/production/wordpress_sites.yml" ]; then
    UPDATED_FILES+=("✓ production/wordpress_sites.yml")
fi
if [ -f "${TRELLIS_DIR}/group_vars/production/main.yml" ]; then
    UPDATED_FILES+=("✓ production/main.yml")
fi
if [ -f "${TRELLIS_DIR}/hosts/production" ]; then
    UPDATED_FILES+=("✓ hosts/production")
fi
if [ -f "${TRELLIS_DIR}/group_vars/development/wordpress_sites.yml" ]; then
    UPDATED_FILES+=("✓ development/wordpress_sites.yml")
fi
if [ "$NEED_STAGING" = "yes" ] || [ "$NEED_STAGING" = "y" ]; then
    if [ -f "${TRELLIS_DIR}/group_vars/staging/vault.yml" ]; then
        UPDATED_FILES+=("✓ staging/vault.yml")
    fi
    if [ -f "${TRELLIS_DIR}/group_vars/staging/wordpress_sites.yml" ]; then
        UPDATED_FILES+=("✓ staging/wordpress_sites.yml")
    fi
    if [ -f "${TRELLIS_DIR}/group_vars/staging/main.yml" ]; then
        UPDATED_FILES+=("✓ staging/main.yml")
    fi
    if [ -f "${TRELLIS_DIR}/hosts/staging" ]; then
        UPDATED_FILES+=("✓ hosts/staging")
    fi
fi

for file in "${UPDATED_FILES[@]}"; do
    echo "  ${file}"
done

echo ""
echo -e "${YELLOW}Important:${NC}"
echo "  - The .vault_pass file has been created in the trellis directory"
echo "  - Keep this file secure and do not commit it to version control"
echo "  - All vault files have been encrypted"
echo ""
echo -e "${YELLOW}Next steps:${NC}"
echo "  1. Review the updated configuration files"
echo "  2. Test your configuration with: cd trellis && ansible-playbook server.yml -e env=development"
echo ""
