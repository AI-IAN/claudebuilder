#!/bin/bash

# ClaudeBuilder - Credential Manager
# Secure credential setup and management

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Configuration
USER_DIR="${CLAUDE_DEV_USER:-$HOME/.claude-dev}"
CREDENTIALS_DIR="$USER_DIR/credentials"
CONFIG_FILE="$USER_DIR/config.json"

# Ensure credentials directory exists
mkdir -p "$CREDENTIALS_DIR"
chmod 700 "$CREDENTIALS_DIR"

echo -e "${BLUE}"
cat << "EOF"
 _______ __                   __         ______            __      
|     __|  |.---.-.--.--.--|  |.-----. |      |.-----.--|  |.-----.
|    |  |  ||  _  |  |  |  _  ||  -__| |   ---||  _  |  _  ||  -__|
|_______|__||___._|_____|_____||_____| |______||_____|_____||_____|
                                                                   
        Secure Credential Management Setup
EOF
echo -e "${NC}"

# Check if running in interactive mode
if [[ -t 0 ]]; then
    INTERACTIVE=true
else
    INTERACTIVE=false
fi

# Function to securely read password
read_password() {
    local prompt="$1"
    local password
    
    echo -n -e "${YELLOW}$prompt${NC}"
    read -s password
    echo
    echo "$password"
}

# Function to read input with default
read_with_default() {
    local prompt="$1"
    local default="$2"
    local value
    
    if [[ -n "$default" ]]; then
        echo -n -e "${YELLOW}$prompt [$default]: ${NC}"
    else
        echo -n -e "${YELLOW}$prompt: ${NC}"
    fi
    
    read value
    echo "${value:-$default}"
}

# Function to encrypt credential
encrypt_credential() {
    local key="$1"
    local value="$2"
    local file="$CREDENTIALS_DIR/$key.enc"
    
    # Use GPG for encryption if available, otherwise base64 (less secure)
    if command -v gpg >/dev/null 2>&1; then
        echo "$value" | gpg --symmetric --cipher-algo AES256 --compress-algo 1 --s2k-mode 3 --s2k-digest-algo SHA512 --s2k-count 65536 --quiet --batch --passphrase "$MASTER_PASSWORD" > "$file"
    else
        echo "$value" | base64 > "$file"
        echo -e "${YELLOW}⚠️ GPG not available, using base64 encoding (less secure)${NC}"
    fi
    
    chmod 600 "$file"
}

# Function to decrypt credential
decrypt_credential() {
    local key="$1"
    local file="$CREDENTIALS_DIR/$key.enc"
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    if command -v gpg >/dev/null 2>&1; then
        gpg --decrypt --quiet --batch --passphrase "$MASTER_PASSWORD" "$file" 2>/dev/null
    else
        base64 -d "$file"
    fi
}

# Function to store credential securely
store_credential() {
    local key="$1"
    local value="$2"
    local description="$3"
    
    if [[ -n "$value" ]]; then
        encrypt_credential "$key" "$value"
        echo -e "${GREEN}✅ Stored: $description${NC}"
        
        # Update credential index
        local index_file="$CREDENTIALS_DIR/index.json"
        local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        
        if [[ -f "$index_file" ]]; then
            local temp_file=$(mktemp)
            jq --arg key "$key" --arg desc "$description" --arg time "$timestamp" \
               '.credentials[$key] = {description: $desc, updated: $time}' \
               "$index_file" > "$temp_file"
            mv "$temp_file" "$index_file"
        else
            jq -n --arg key "$key" --arg desc "$description" --arg time "$timestamp" \
               '{credentials: {($key): {description: $desc, updated: $time}}}' \
               > "$index_file"
        fi
    else
        echo -e "${YELLOW}⚠️ Skipped: $description (empty value)${NC}"
    fi
}

# Function to load existing credential
load_credential() {
    local key="$1"
    decrypt_credential "$key" 2>/dev/null || echo ""
}

# GitHub credential setup
setup_github() {
    echo -e "${BLUE}🐙 GitHub Configuration${NC}"
    echo "=================================="
    
    # Check if GitHub CLI is authenticated
    if gh auth status >/dev/null 2>&1; then
        echo -e "${GREEN}✅ GitHub CLI already authenticated${NC}"
        
        # Get GitHub username and token from CLI
        GITHUB_USERNAME=$(gh api user --jq .login 2>/dev/null || echo "")
        
        if [[ -n "$GITHUB_USERNAME" ]]; then
            store_credential "github_username" "$GITHUB_USERNAME" "GitHub Username"
            echo -e "${GREEN}✅ GitHub username: $GITHUB_USERNAME${NC}"
        fi
    else
        echo -e "${YELLOW}📋 GitHub authentication required${NC}"
        echo
        echo "Please visit: https://github.com/settings/personal-access-tokens/new"
        echo "Required scopes: repo, read:org, workflow, admin:public_key"
        echo
        
        local github_token
        github_token=$(read_password "GitHub Personal Access Token: ")
        
        if [[ -n "$github_token" ]]; then
            # Set token for GitHub CLI
            echo "$github_token" | gh auth login --with-token
            
            # Store token securely
            store_credential "github_token" "$github_token" "GitHub Personal Access Token"
            
            # Get username
            GITHUB_USERNAME=$(gh api user --jq .login)
            store_credential "github_username" "$GITHUB_USERNAME" "GitHub Username"
            
            echo -e "${GREEN}✅ GitHub authentication successful${NC}"
        fi
    fi
    
    # Default organization
    local current_org=$(load_credential "github_default_org")
    local github_org
    github_org=$(read_with_default "Default GitHub Organization" "$current_org")
    store_credential "github_default_org" "$github_org" "Default GitHub Organization"
    
    echo
}

# Cloud provider credentials
setup_cloud_providers() {
    echo -e "${BLUE}☁️ Cloud Provider Configuration${NC}"
    echo "===================================="
    
    # AWS
    echo -e "${YELLOW}📋 AWS Credentials (Optional)${NC}"
    local aws_access_key=$(load_credential "aws_access_key_id")
    local new_aws_key
    new_aws_key=$(read_with_default "AWS Access Key ID" "$aws_access_key")
    
    if [[ -n "$new_aws_key" ]]; then
        store_credential "aws_access_key_id" "$new_aws_key" "AWS Access Key ID"
        
        local aws_secret
        aws_secret=$(read_password "AWS Secret Access Key: ")
        store_credential "aws_secret_access_key" "$aws_secret" "AWS Secret Access Key"
        
        local aws_region=$(load_credential "aws_region")
        local new_region
        new_region=$(read_with_default "AWS Default Region" "${aws_region:-us-east-1}")
        store_credential "aws_region" "$new_region" "AWS Default Region"
    fi
    
    # Google Cloud (optional)
    echo -e "${YELLOW}📋 Google Cloud Credentials (Optional)${NC}"
    local gcp_project=$(load_credential "gcp_project_id")
    local new_gcp_project
    new_gcp_project=$(read_with_default "GCP Project ID" "$gcp_project")
    
    if [[ -n "$new_gcp_project" ]]; then
        store_credential "gcp_project_id" "$new_gcp_project" "GCP Project ID"
        echo "Note: Use 'gcloud auth login' for authentication"
    fi
    
    # Azure (optional)
    echo -e "${YELLOW}📋 Azure Credentials (Optional)${NC}"
    local azure_subscription=$(load_credential "azure_subscription_id")
    local new_azure_sub
    new_azure_sub=$(read_with_default "Azure Subscription ID" "$azure_subscription")
    
    if [[ -n "$new_azure_sub" ]]; then
        store_credential "azure_subscription_id" "$new_azure_sub" "Azure Subscription ID"
        echo "Note: Use 'az login' for authentication"
    fi
    
    echo
}

# Database credentials
setup_databases() {
    echo -e "${BLUE}🗄️ Database Configuration${NC}"
    echo "============================"
    
    # PostgreSQL
    echo -e "${YELLOW}📋 PostgreSQL (Optional)${NC}"
    local pg_url=$(load_credential "postgresql_url")
    local new_pg_url
    new_pg_url=$(read_with_default "PostgreSQL Connection URL" "$pg_url")
    store_credential "postgresql_url" "$new_pg_url" "PostgreSQL Connection URL"
    
    # Redis
    echo -e "${YELLOW}📋 Redis (Optional)${NC}"
    local redis_url=$(load_credential "redis_url")
    local new_redis_url
    new_redis_url=$(read_with_default "Redis Connection URL" "${redis_url:-redis://localhost:6379}")
    store_credential "redis_url" "$new_redis_url" "Redis Connection URL"
    
    # MongoDB
    echo -e "${YELLOW}📋 MongoDB (Optional)${NC}"
    local mongo_url=$(load_credential "mongodb_url")
    local new_mongo_url
    new_mongo_url=$(read_with_default "MongoDB Connection URL" "$mongo_url")
    store_credential "mongodb_url" "$new_mongo_url" "MongoDB Connection URL"
    
    echo
}

# API keys for external services
setup_api_keys() {
    echo -e "${BLUE}🔑 API Keys Configuration${NC}"
    echo "=========================="
    
    # OpenAI
    echo -e "${YELLOW}📋 OpenAI API Key (Optional)${NC}"
    local openai_key=$(load_credential "openai_api_key")
    if [[ -z "$openai_key" ]]; then
        local new_openai_key
        new_openai_key=$(read_password "OpenAI API Key (sk-...): ")
        store_credential "openai_api_key" "$new_openai_key" "OpenAI API Key"
    else
        echo -e "${GREEN}✅ OpenAI API Key already configured${NC}"
    fi
    
    # Anthropic
    echo -e "${YELLOW}📋 Anthropic API Key (Optional)${NC}"
    local anthropic_key=$(load_credential "anthropic_api_key")
    if [[ -z "$anthropic_key" ]]; then
        local new_anthropic_key
        new_anthropic_key=$(read_password "Anthropic API Key: ")
        store_credential "anthropic_api_key" "$new_anthropic_key" "Anthropic API Key"
    else
        echo -e "${GREEN}✅ Anthropic API Key already configured${NC}"
    fi
    
    # Docker Hub
    echo -e "${YELLOW}📋 Docker Hub (Optional)${NC}"
    local docker_username=$(load_credential "docker_username")
    local new_docker_user
    new_docker_user=$(read_with_default "Docker Hub Username" "$docker_username")
    
    if [[ -n "$new_docker_user" ]]; then
        store_credential "docker_username" "$new_docker_user" "Docker Hub Username"
        
        local docker_password
        docker_password=$(read_password "Docker Hub Password/Token: ")
        store_credential "docker_password" "$docker_password" "Docker Hub Password"
    fi
    
    echo
}

# SSH key management
setup_ssh_keys() {
    echo -e "${BLUE}🔐 SSH Key Management${NC}"
    echo "======================"
    
    local ssh_dir="$HOME/.ssh"
    mkdir -p "$ssh_dir"
    chmod 700 "$ssh_dir"
    
    # Check for existing SSH keys
    if [[ -f "$ssh_dir/id_rsa.pub" ]] || [[ -f "$ssh_dir/id_ed25519.pub" ]]; then
        echo -e "${GREEN}✅ SSH keys already exist${NC}"
        
        # Add to GitHub if not already added
        if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
            echo -e "${YELLOW}📋 Adding SSH key to GitHub...${NC}"
            
            local pub_key=""
            if [[ -f "$ssh_dir/id_ed25519.pub" ]]; then
                pub_key="$ssh_dir/id_ed25519.pub"
            elif [[ -f "$ssh_dir/id_rsa.pub" ]]; then
                pub_key="$ssh_dir/id_rsa.pub"
            fi
            
            if [[ -n "$pub_key" ]]; then
                local key_title="claude-dev-$(hostname)-$(date +%Y%m%d)"
                gh ssh-key add "$pub_key" --title "$key_title" 2>/dev/null || true
                echo -e "${GREEN}✅ SSH key added to GitHub${NC}"
            fi
        fi
    else
        echo -e "${YELLOW}📋 Generating new SSH key...${NC}"
        local email
        email=$(read_with_default "Email for SSH key" "$(git config --global user.email)")
        
        if [[ -n "$email" ]]; then
            ssh-keygen -t ed25519 -C "$email" -f "$ssh_dir/id_ed25519" -N ""
            chmod 600 "$ssh_dir/id_ed25519"
            chmod 644 "$ssh_dir/id_ed25519.pub"
            
            # Add to ssh-agent
            eval "$(ssh-agent -s)" >/dev/null 2>&1
            ssh-add "$ssh_dir/id_ed25519" >/dev/null 2>&1
            
            echo -e "${GREEN}✅ SSH key generated${NC}"
            
            # Add to GitHub
            if command -v gh >/dev/null 2>&1 && gh auth status >/dev/null 2>&1; then
                local key_title="claude-dev-$(hostname)-$(date +%Y%m%d)"
                gh ssh-key add "$ssh_dir/id_ed25519.pub" --title "$key_title"
                echo -e "${GREEN}✅ SSH key added to GitHub${NC}"
            fi
        fi
    fi
    
    echo
}

# Create environment files for projects
create_env_template() {
    echo -e "${BLUE}📝 Creating Environment Templates${NC}"
    echo "=================================="
    
    # Global environment template
    cat > "$USER_DIR/.env.global" << 'EOF'
# Global Environment Variables
# These are loaded for all projects

# GitHub Configuration
GITHUB_USERNAME=$(decrypt_credential github_username)
GITHUB_TOKEN=$(decrypt_credential github_token)
GITHUB_DEFAULT_ORG=$(decrypt_credential github_default_org)

# Cloud Provider Credentials
AWS_ACCESS_KEY_ID=$(decrypt_credential aws_access_key_id)
AWS_SECRET_ACCESS_KEY=$(decrypt_credential aws_secret_access_key)
AWS_DEFAULT_REGION=$(decrypt_credential aws_region)

GCP_PROJECT_ID=$(decrypt_credential gcp_project_id)
AZURE_SUBSCRIPTION_ID=$(decrypt_credential azure_subscription_id)

# Database URLs
DATABASE_URL=$(decrypt_credential postgresql_url)
REDIS_URL=$(decrypt_credential redis_url)
MONGODB_URL=$(decrypt_credential mongodb_url)

# API Keys
OPENAI_API_KEY=$(decrypt_credential openai_api_key)
ANTHROPIC_API_KEY=$(decrypt_credential anthropic_api_key)

# Docker Configuration
DOCKER_USERNAME=$(decrypt_credential docker_username)
DOCKER_PASSWORD=$(decrypt_credential docker_password)
EOF
    
    # Project-specific template
    cat > "$USER_DIR/.env.project.template" << 'EOF'
# Project-Specific Environment Variables
# Copy this to your project as .env and customize

# Project Configuration
PROJECT_NAME=my-project
PROJECT_COMPLEXITY=standard
PROJECT_TYPE=web

# Development Configuration
NODE_ENV=development
DEBUG=true
LOG_LEVEL=debug

# Database Configuration (override global if needed)
# DATABASE_URL=postgresql://localhost:5432/my_project_dev
# REDIS_URL=redis://localhost:6379/1

# API Configuration
API_PORT=3000
API_HOST=localhost

# Frontend Configuration
FRONTEND_PORT=3001
FRONTEND_HOST=localhost

# Security
JWT_SECRET=your-jwt-secret-here
SESSION_SECRET=your-session-secret-here

# External Services (project-specific keys)
# STRIPE_SECRET_KEY=sk_test_...
# SENDGRID_API_KEY=SG....
# TWILIO_ACCOUNT_SID=AC...
EOF
    
    echo -e "${GREEN}✅ Environment templates created${NC}"
    echo
}

# Generate credential access functions
create_credential_functions() {
    echo -e "${BLUE}🛠️ Creating Credential Access Functions${NC}"
    echo "======================================="
    
    # Create credential helper script
    cat > "$CREDENTIALS_DIR/helper.sh" << 'EOF'
#!/bin/bash

# ClaudeBuilder - Credential Helper Functions
# Source this file to access credentials in your scripts

CREDENTIALS_DIR="$(dirname "${BASH_SOURCE[0]}")"
MASTER_PASSWORD_FILE="$CREDENTIALS_DIR/.master"

# Function to get master password
get_master_password() {
    if [[ -f "$MASTER_PASSWORD_FILE" ]]; then
        cat "$MASTER_PASSWORD_FILE"
    else
        echo "default_password_change_me"
    fi
}

# Function to decrypt and get credential
get_credential() {
    local key="$1"
    local file="$CREDENTIALS_DIR/$key.enc"
    local master_password=$(get_master_password)
    
    if [[ ! -f "$file" ]]; then
        return 1
    fi
    
    if command -v gpg >/dev/null 2>&1; then
        gpg --decrypt --quiet --batch --passphrase "$master_password" "$file" 2>/dev/null
    else
        base64 -d "$file"
    fi
}

# Convenience functions for common credentials
github_token() { get_credential "github_token"; }
github_username() { get_credential "github_username"; }
github_org() { get_credential "github_default_org"; }

aws_access_key() { get_credential "aws_access_key_id"; }
aws_secret_key() { get_credential "aws_secret_access_key"; }
aws_region() { get_credential "aws_region"; }

database_url() { get_credential "postgresql_url"; }
redis_url() { get_credential "redis_url"; }
mongodb_url() { get_credential "mongodb_url"; }

openai_key() { get_credential "openai_api_key"; }
anthropic_key() { get_credential "anthropic_api_key"; }

# Function to load all credentials into environment
load_credentials() {
    export GITHUB_TOKEN=$(github_token)
    export GITHUB_USERNAME=$(github_username)
    export GITHUB_DEFAULT_ORG=$(github_org)
    
    export AWS_ACCESS_KEY_ID=$(aws_access_key)
    export AWS_SECRET_ACCESS_KEY=$(aws_secret_key)
    export AWS_DEFAULT_REGION=$(aws_region)
    
    export DATABASE_URL=$(database_url)
    export REDIS_URL=$(redis_url)
    export MONGODB_URL=$(mongodb_url)
    
    export OPENAI_API_KEY=$(openai_key)
    export ANTHROPIC_API_KEY=$(anthropic_key)
}

# Function to verify credentials
verify_credentials() {
    echo "🔍 Verifying credentials..."
    
    # GitHub
    if [[ -n "$(github_token)" ]]; then
        echo "✅ GitHub token configured"
        if gh auth status >/dev/null 2>&1; then
            echo "✅ GitHub CLI authenticated"
        else
            echo "⚠️ GitHub CLI not authenticated"
        fi
    else
        echo "❌ GitHub token not configured"
    fi
    
    # AWS
    if [[ -n "$(aws_access_key)" ]]; then
        echo "✅ AWS credentials configured"
    else
        echo "ℹ️ AWS credentials not configured"
    fi
    
    # Database
    if [[ -n "$(database_url)" ]]; then
        echo "✅ Database URL configured"
    else
        echo "ℹ️ Database URL not configured"
    fi
}
EOF
    
    chmod +x "$CREDENTIALS_DIR/helper.sh"
    echo -e "${GREEN}✅ Credential helper functions created${NC}"
    echo
}

# Set master password for encryption
setup_master_password() {
    echo -e "${BLUE}🔐 Master Password Setup${NC}"
    echo "========================="
    
    local master_file="$CREDENTIALS_DIR/.master"
    
    if [[ -f "$master_file" ]]; then
        echo -e "${GREEN}✅ Master password already configured${NC}"
        MASTER_PASSWORD=$(cat "$master_file")
    else
        echo -e "${YELLOW}📋 Setting up encryption master password${NC}"
        echo "This password will be used to encrypt your stored credentials."
        echo
        
        local password1
        local password2
        
        password1=$(read_password "Enter master password: ")
        password2=$(read_password "Confirm master password: ")
        
        if [[ "$password1" == "$password2" ]]; then
            echo "$password1" > "$master_file"
            chmod 600 "$master_file"
            MASTER_PASSWORD="$password1"
            echo -e "${GREEN}✅ Master password configured${NC}"
        else
            echo -e "${RED}❌ Passwords don't match${NC}"
            exit 1
        fi
    fi
    
    echo
}

# List configured credentials
list_credentials() {
    echo -e "${BLUE}📋 Configured Credentials${NC}"
    echo "=========================="
    
    local index_file="$CREDENTIALS_DIR/index.json"
    
    if [[ -f "$index_file" ]]; then
        echo "Credential | Description | Last Updated"
        echo "-----------|-------------|-------------"
        
        jq -r '.credentials | to_entries[] | "\(.key) | \(.value.description) | \(.value.updated)"' "$index_file" | \
        while IFS=' | ' read -r key desc updated; do
            printf "%-15s | %-25s | %s\n" "$key" "$desc" "$updated"
        done
    else
        echo "No credentials configured yet."
    fi
    
    echo
}

# Main setup flow
main() {
    echo -e "${YELLOW}⚠️ This will configure credentials for ClaudeBuilder${NC}"
    echo
    
    if [[ "$1" == "--list" ]]; then
        setup_master_password
        list_credentials
        exit 0
    fi
    
    if [[ "$1" == "--verify" ]]; then
        setup_master_password
        source "$CREDENTIALS_DIR/helper.sh"
        verify_credentials
        exit 0
    fi
    
    # Interactive setup
    if [[ "$INTERACTIVE" == "true" ]]; then
        echo -e "${YELLOW}Press Enter to continue or Ctrl+C to cancel...${NC}"
        read
    fi
    
    setup_master_password
    setup_github
    setup_ssh_keys
    setup_cloud_providers
    setup_databases
    setup_api_keys
    create_env_template
    create_credential_functions
    
    echo -e "${GREEN}🎉 Credential setup complete!${NC}"
    echo "================================"
    echo
    echo -e "${BLUE}📋 Summary:${NC}"
    list_credentials
    
    echo -e "${BLUE}🛠️ Usage:${NC}"
    echo "  • Access credentials: source $CREDENTIALS_DIR/helper.sh"
    echo "  • Verify setup: setup-credentials --verify"
    echo "  • List credentials: setup-credentials --list"
    echo "  • Update credentials: setup-credentials (run again)"
    echo
    echo -e "${YELLOW}⚠️ Security Notes:${NC}"
    echo "  • Credentials are encrypted with your master password"
    echo "  • Master password is stored locally (keep it secure)"
    echo "  • Never commit .env files or credential files to git"
    echo "  • Regularly rotate your API keys and tokens"
    echo
}

# Handle command line arguments
case "${1:-}" in
    --list)
        main --list
        ;;
    --verify)
        main --verify
        ;;
    --help)
        echo "Usage: setup-credentials [--list|--verify|--help]"
        echo
        echo "Options:"
        echo "  --list     List configured credentials"
        echo "  --verify   Verify credential configuration"
        echo "  --help     Show this help message"
        echo
        echo "Run without arguments for interactive setup."
        ;;
    *)
        main "$@"
        ;;
esac