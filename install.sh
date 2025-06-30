#!/bin/bash

# ClaudeBuilder - Master Installation Script
# Run with: curl -sSL https://your-repo.com/install.sh | bash

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m' # No Color

# Configuration
SYSTEM_DIR="/opt/claude-dev-system"
USER_DIR="$HOME/.claude-dev"
REPO_URL="https://github.com/ianjacobs/claudebuilder.git"
VERSION="latest"

echo -e "${BLUE}"
cat << "EOF"
 _______ __                   __         ______            __      
|     __|  |.---.-.--.--.--|  |.-----. |      |.-----.--|  |.-----.
|    |  |  ||  _  |  |  |  _  ||  -__| |   ---||  _  |  _  ||  -__|
|_______|__||___._|_____|_____||_____| |______||_____|_____||_____|
                                                                   
   Autonomous Development System Installation
EOF
echo -e "${NC}"

echo -e "${BLUE}🚀 Starting ClaudeBuilder Installation${NC}"
echo "================================================================"

# Check if running as root (for server installation)
if [[ $EUID -eq 0 ]]; then
    INSTALL_MODE="server"
    SYSTEM_USER="root"
    echo -e "${YELLOW}📋 Server installation mode detected${NC}"
else
    INSTALL_MODE="local"
    SYSTEM_USER="$USER"
    echo -e "${YELLOW}📋 Local installation mode detected${NC}"
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to install package if not exists
install_package() {
    local package=$1
    local install_cmd=$2
    
    if command_exists "$package"; then
        echo -e "${GREEN}✅ $package${NC}: Already installed"
    else
        echo -e "${YELLOW}📦 Installing $package...${NC}"
        eval "$install_cmd"
        if command_exists "$package"; then
            echo -e "${GREEN}✅ $package${NC}: Successfully installed"
        else
            echo -e "${RED}❌ $package${NC}: Installation failed"
            exit 1
        fi
    fi
}

# System detection
detect_system() {
    if [[ "$OSTYPE" == "linux-gnu"* ]]; then
        if command_exists apt; then
            PACKAGE_MANAGER="apt"
            UPDATE_CMD="sudo apt update && sudo apt upgrade -y"
        elif command_exists yum; then
            PACKAGE_MANAGER="yum"
            UPDATE_CMD="sudo yum update -y"
        else
            echo -e "${RED}❌ Unsupported Linux distribution${NC}"
            exit 1
        fi
    elif [[ "$OSTYPE" == "darwin"* ]]; then
        PACKAGE_MANAGER="brew"
        UPDATE_CMD="brew update && brew upgrade"
        if ! command_exists brew; then
            echo -e "${YELLOW}📦 Installing Homebrew...${NC}"
            /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
        fi
    else
        echo -e "${RED}❌ Unsupported operating system${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ System detected${NC}: $OSTYPE with $PACKAGE_MANAGER"
}

# Create directory structure
setup_directories() {
    echo -e "${BLUE}📁 Setting up directory structure...${NC}"
    
    # System directories
    sudo mkdir -p "$SYSTEM_DIR"/{scripts,templates,configs,tools,docs}
    sudo mkdir -p "$USER_DIR"/{projects,credentials,logs,backups}
    
    # User-specific directories
    mkdir -p "$HOME/.config/claude-dev"
    mkdir -p "$HOME/.local/bin"
    
    # Set proper permissions
    if [[ $INSTALL_MODE == "server" ]]; then
        sudo chown -R $SYSTEM_USER:$SYSTEM_USER "$SYSTEM_DIR"
        sudo chown -R $SYSTEM_USER:$SYSTEM_USER "$USER_DIR"
    fi
    
    echo -e "${GREEN}✅ Directory structure created${NC}"
}

# Install core dependencies
install_dependencies() {
    echo -e "${BLUE}🔧 Installing core dependencies...${NC}"
    
    # Update system
    echo -e "${YELLOW}📦 Updating system packages...${NC}"
    eval "$UPDATE_CMD"
    
    # Essential tools
    if [[ $PACKAGE_MANAGER == "apt" ]]; then
        install_package "curl" "sudo apt install -y curl"
        install_package "wget" "sudo apt install -y wget"
        install_package "git" "sudo apt install -y git"
        install_package "jq" "sudo apt install -y jq"
        install_package "unzip" "sudo apt install -y unzip"
    elif [[ $PACKAGE_MANAGER == "brew" ]]; then
        install_package "curl" "brew install curl"
        install_package "wget" "brew install wget"
        install_package "git" "brew install git"
        install_package "jq" "brew install jq"
        install_package "unzip" "brew install unzip"
    fi
    
    # Node.js and npm
    if ! command_exists node; then
        echo -e "${YELLOW}📦 Installing Node.js...${NC}"
        if [[ $PACKAGE_MANAGER == "apt" ]]; then
            curl -fsSL https://deb.nodesource.com/setup_20.x | sudo -E bash -
            sudo apt-get install -y nodejs
        elif [[ $PACKAGE_MANAGER == "brew" ]]; then
            brew install node
        fi
    fi
    
    # Python and pip
    if [[ $PACKAGE_MANAGER == "apt" ]]; then
        install_package "python3" "sudo apt install -y python3 python3-pip"
    elif [[ $PACKAGE_MANAGER == "brew" ]]; then
        install_package "python3" "brew install python"
    fi
    
    # Docker (for server installations)
    if [[ $INSTALL_MODE == "server" ]] && ! command_exists docker; then
        echo -e "${YELLOW}📦 Installing Docker...${NC}"
        curl -fsSL https://get.docker.com -o get-docker.sh
        sudo sh get-docker.sh
        sudo usermod -aG docker $SYSTEM_USER
        rm get-docker.sh
    fi
    
    # GitHub CLI
    if ! command_exists gh; then
        echo -e "${YELLOW}📦 Installing GitHub CLI...${NC}"
        if [[ $PACKAGE_MANAGER == "apt" ]]; then
            curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg
            echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" | sudo tee /etc/apt/sources.list.d/github-cli.list > /dev/null
            sudo apt update
            sudo apt install gh
        elif [[ $PACKAGE_MANAGER == "brew" ]]; then
            brew install gh
        fi
    fi
}

# Install Claude Code CLI
install_claude_code() {
    echo -e "${BLUE}🤖 Installing Claude Code CLI...${NC}"
    
    if command_exists claude; then
        echo -e "${GREEN}✅ Claude Code CLI${NC}: Already installed"
        return
    fi
    
    # Download and install Claude Code CLI
    echo -e "${YELLOW}📦 Downloading Claude Code CLI...${NC}"
    
    # Detect architecture
    ARCH=$(uname -m)
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    
    case $ARCH in
        x86_64) ARCH="amd64" ;;
        aarch64|arm64) ARCH="arm64" ;;
        *) echo -e "${RED}❌ Unsupported architecture: $ARCH${NC}"; exit 1 ;;
    esac
    
    # Download URL (adjust based on actual Anthropic distribution)
    CLAUDE_URL="https://anthropic.com/claude-code/releases/latest/claude-code-${OS}-${ARCH}.tar.gz"
    
    # Create temporary directory
    TEMP_DIR=$(mktemp -d)
    cd "$TEMP_DIR"
    
    # Download and extract
    wget -O claude-code.tar.gz "$CLAUDE_URL" || {
        echo -e "${RED}❌ Failed to download Claude Code CLI${NC}"
        echo -e "${YELLOW}ℹ️ Please install Claude Code CLI manually${NC}"
        cd - > /dev/null
        rm -rf "$TEMP_DIR"
        return
    }
    
    tar -xzf claude-code.tar.gz
    
    # Install
    sudo mv claude /usr/local/bin/
    sudo chmod +x /usr/local/bin/claude
    
    # Cleanup
    cd - > /dev/null
    rm -rf "$TEMP_DIR"
    
    if command_exists claude; then
        echo -e "${GREEN}✅ Claude Code CLI${NC}: Successfully installed"
    else
        echo -e "${RED}❌ Claude Code CLI installation failed${NC}"
        exit 1
    fi
}

# Download system files
download_system_files() {
    echo -e "${BLUE}📥 Downloading system files...${NC}"
    
    # Clone or download the system repository
    cd /tmp
    if [[ -d claude-dev-system ]]; then
        rm -rf claude-dev-system
    fi
    
    git clone "$REPO_URL" claude-dev-system || {
        echo -e "${RED}❌ Failed to download system files${NC}"
        exit 1
    }
    
    # Copy files to system directory
    sudo cp -r claude-dev-system/* "$SYSTEM_DIR/"
    sudo chown -R $SYSTEM_USER:$SYSTEM_USER "$SYSTEM_DIR"
    
    # Make scripts executable
    sudo chmod +x "$SYSTEM_DIR"/scripts/*.sh
    sudo chmod +x "$SYSTEM_DIR"/tools/*.sh
    
    # Cleanup
    rm -rf claude-dev-system
    
    echo -e "${GREEN}✅ System files downloaded${NC}"
}

# Setup PATH and aliases
setup_environment() {
    echo -e "${BLUE}⚙️ Setting up environment...${NC}"
    
    # Add system scripts to PATH
    SHELL_RC="$HOME/.bashrc"
    if [[ "$SHELL" == *"zsh"* ]]; then
        SHELL_RC="$HOME/.zshrc"
    fi
    
    # Check if already configured
    if ! grep -q "claude-dev-system" "$SHELL_RC"; then
        cat >> "$SHELL_RC" << EOF

# ClaudeBuilder
export CLAUDE_DEV_SYSTEM="$SYSTEM_DIR"
export CLAUDE_DEV_USER="$USER_DIR"
export PATH="\$CLAUDE_DEV_SYSTEM/scripts:\$CLAUDE_DEV_SYSTEM/tools:\$PATH"

# Claude Development Aliases
alias create-project="$SYSTEM_DIR/scripts/create-project.sh"
alias setup-credentials="$SYSTEM_DIR/scripts/setup-credentials.sh"
alias claude-health="$SYSTEM_DIR/tools/health-check.sh"
alias claude-update="$SYSTEM_DIR/scripts/update-system.sh"
alias cdp="cd $USER_DIR/projects"

# Git shortcuts
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git log --oneline'

# Development shortcuts
alias ll='ls -alF'
alias ..='cd ..'
alias ...='cd ../..'
EOF
    fi
    
    # Create symlinks for easy access
    sudo ln -sf "$SYSTEM_DIR/scripts/create-project.sh" /usr/local/bin/create-project
    sudo ln -sf "$SYSTEM_DIR/scripts/setup-credentials.sh" /usr/local/bin/setup-credentials
    sudo ln -sf "$SYSTEM_DIR/tools/health-check.sh" /usr/local/bin/claude-health
    
    echo -e "${GREEN}✅ Environment configured${NC}"
}

# Create initial configuration
create_initial_config() {
    echo -e "${BLUE}📝 Creating initial configuration...${NC}"
    
    # Create system configuration
    cat > "$USER_DIR/config.json" << EOF
{
  "version": "$VERSION",
  "install_date": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "install_mode": "$INSTALL_MODE",
  "system_dir": "$SYSTEM_DIR",
  "user_dir": "$USER_DIR",
  "default_complexity": "standard",
  "auto_github": true,
  "auto_commit": true,
  "template_repo": "$REPO_URL"
}
EOF
    
    # Create environment template
    cat > "$USER_DIR/.env.template" << 'EOF'
# ClaudeBuilder Environment Variables

# GitHub Configuration
GITHUB_TOKEN=your_github_personal_access_token
GITHUB_USERNAME=your_github_username
GITHUB_DEFAULT_ORG=your_default_organization

# Cloud Provider Credentials (Optional)
AWS_ACCESS_KEY_ID=your_aws_access_key
AWS_SECRET_ACCESS_KEY=your_aws_secret_key
AWS_REGION=us-east-1

# Database Configuration (Optional)
DATABASE_URL=postgresql://user:pass@localhost:5432/dbname
REDIS_URL=redis://localhost:6379

# API Keys (Optional)
OPENAI_API_KEY=your_openai_api_key
ANTHROPIC_API_KEY=your_anthropic_api_key

# Development Configuration
DEFAULT_COMPLEXITY=standard
AUTO_DEPLOY=false
ENABLE_MONITORING=true
EOF
    
    echo -e "${GREEN}✅ Initial configuration created${NC}"
}

# Verify installation
verify_installation() {
    echo -e "${BLUE}🔍 Verifying installation...${NC}"
    
    local issues=0
    
    # Check required commands
    local required_commands=("git" "node" "npm" "python3" "jq" "gh")
    for cmd in "${required_commands[@]}"; do
        if command_exists "$cmd"; then
            echo -e "${GREEN}✅ $cmd${NC}: Available"
        else
            echo -e "${RED}❌ $cmd${NC}: Missing"
            ((issues++))
        fi
    done
    
    # Check Claude Code CLI
    if command_exists claude; then
        echo -e "${GREEN}✅ Claude Code CLI${NC}: Available"
    else
        echo -e "${YELLOW}⚠️ Claude Code CLI${NC}: Not available (install manually if needed)"
    fi
    
    # Check directories
    local required_dirs=("$SYSTEM_DIR" "$USER_DIR" "$USER_DIR/projects")
    for dir in "${required_dirs[@]}"; do
        if [[ -d "$dir" ]]; then
            echo -e "${GREEN}✅ Directory${NC}: $dir"
        else
            echo -e "${RED}❌ Directory${NC}: $dir missing"
            ((issues++))
        fi
    done
    
    # Check system files
    local required_files=("$SYSTEM_DIR/scripts/create-project.sh" "$USER_DIR/config.json")
    for file in "${required_files[@]}"; do
        if [[ -f "$file" ]]; then
            echo -e "${GREEN}✅ File${NC}: $(basename "$file")"
        else
            echo -e "${RED}❌ File${NC}: $file missing"
            ((issues++))
        fi
    done
    
    if [[ $issues -eq 0 ]]; then
        echo -e "${GREEN}✅ Installation verification passed${NC}"
        return 0
    else
        echo -e "${RED}❌ Installation verification failed with $issues issues${NC}"
        return 1
    fi
}

# Display completion message
show_completion() {
    echo
    echo -e "${GREEN}🎉 ClaudeBuilder Installation Complete!${NC}"
    echo "=============================================================="
    echo
    echo -e "${BLUE}📋 What was installed:${NC}"
    echo "  • Core development tools (Git, Node.js, Python, Docker)"
    echo "  • GitHub CLI for repository management"
    echo "  • Claude Code CLI for autonomous development"
    echo "  • Project templates (minimal, standard, enterprise)"
    echo "  • Automated scripts and tools"
    echo "  • Secure credential management system"
    echo
    echo -e "${BLUE}📁 System locations:${NC}"
    echo "  • System files: $SYSTEM_DIR"
    echo "  • User data: $USER_DIR"
    echo "  • Projects: $USER_DIR/projects"
    echo "  • Configuration: $USER_DIR/config.json"
    echo
    echo -e "${BLUE}🚀 Next steps:${NC}"
    echo "  1. Restart your shell or run: source ~/.bashrc"
    echo "  2. Set up your credentials: setup-credentials"
    echo "  3. Create your first project: create-project"
    echo "  4. Verify system health: claude-health"
    echo
    echo -e "${BLUE}📚 Quick commands:${NC}"
    echo "  • create-project          - Interactive project creation"
    echo "  • setup-credentials       - Configure GitHub and other credentials"  
    echo "  • claude-health          - Check system status"
    echo "  • claude-update          - Update system to latest version"
    echo
    echo -e "${YELLOW}⚠️ Important:${NC} Run 'setup-credentials' to configure GitHub integration"
    echo
    echo -e "${PURPLE}🔗 Documentation:${NC} https://github.com/ianjacobs/claudebuilder"
    echo
}

# Main installation flow
main() {
    detect_system
    setup_directories
    install_dependencies
    install_claude_code
    download_system_files
    setup_environment
    create_initial_config
    
    if verify_installation; then
        show_completion
    else
        echo -e "${RED}❌ Installation completed with issues. Please check the output above.${NC}"
        exit 1
    fi
}

# Run installation
main "$@"