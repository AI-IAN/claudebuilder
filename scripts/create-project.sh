#!/bin/bash

# ClaudeBuilder - Project Creation Script
set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

USER_DIR="${CLAUDE_DEV_USER:-/root/.claude-dev}"
PROJECTS_DIR="$USER_DIR/projects"

echo -e "${BLUE}🚀 ClaudeBuilder Project Creator${NC}"

# Parse arguments
PROJECT_NAME=""
PROJECT_TYPE=""
COMPLEXITY=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --name) PROJECT_NAME="$2"; shift 2 ;;
        --type) PROJECT_TYPE="$2"; shift 2 ;;
        --complexity) COMPLEXITY="$2"; shift 2 ;;
        --help)
            echo "Usage: create-project --name NAME --type TYPE --complexity LEVEL"
            echo "Types: web, api, mobile, data, ml"
            echo "Complexity: minimal, standard, enterprise"
            exit 0 ;;
        *) echo "Unknown option: $1"; exit 1 ;;
    esac
done

# Validate required arguments
if [[ -z "$PROJECT_NAME" || -z "$PROJECT_TYPE" || -z "$COMPLEXITY" ]]; then
    echo -e "${RED}❌ Missing required arguments${NC}"
    echo "Usage: create-project --name NAME --type TYPE --complexity LEVEL"
    exit 1
fi

# Create project
echo "Creating project: $PROJECT_NAME ($PROJECT_TYPE, $COMPLEXITY)"

PROJECT_DIR="$PROJECTS_DIR/$PROJECT_NAME"
mkdir -p "$PROJECT_DIR"
cd "$PROJECT_DIR"

# Initialize git
git init
git branch -M main

# Create structure
mkdir -p {src,tests,docs,scripts}

# Create README
cat > README.md << 'READMEEOF'
# ${PROJECT_NAME}

${PROJECT_TYPE} project built with ClaudeBuilder (${COMPLEXITY} complexity)

## Getting Started

This project was created with ClaudeBuilder for autonomous development.

## Next Steps

1. Run: claude --interactive
2. Start developing with natural language commands
3. Follow the complexity guidelines in claude.md

READMEEOF

# Create claude.md
cat > claude.md << 'CLAUDEEOF'
# ClaudeBuilder Development Instructions

## Project Configuration
- **Name**: ${PROJECT_NAME}
- **Type**: ${PROJECT_TYPE} 
- **Complexity**: ${COMPLEXITY}

## Development Guidelines

Build ${PROJECT_NAME} as a ${COMPLEXITY} complexity ${PROJECT_TYPE} project.

### ${COMPLEXITY} Complexity Rules:
$(if [[ "$COMPLEXITY" == "minimal" ]]; then
    echo "- Timeline: 1-3 hours maximum"
    echo "- Core functionality only"
    echo "- Simple tech stack"
    echo "- No authentication required"
elif [[ "$COMPLEXITY" == "standard" ]]; then
    echo "- Timeline: 1-3 days maximum"
    echo "- Production-ready features"
    echo "- Modern tech stack"
    echo "- Basic authentication"
    echo "- Docker deployment"
else
    echo "- Timeline: 1-2 weeks maximum"
    echo "- Enterprise features"
    echo "- Microservices architecture"
    echo "- Advanced security"
fi)

### Development Commands:
"Implement feature: [description] for ${PROJECT_NAME} following ${COMPLEXITY} complexity guidelines"

"Add comprehensive testing with proper error handling"

"Deploy to staging environment with monitoring"

### Success Criteria:
- All features working as specified
- Comprehensive error handling
- Security best practices
- Documentation complete
- Deployment ready

**Stay within ${COMPLEXITY} complexity scope to avoid feature creep.**
CLAUDEEOF

# Create package.json for web/api projects
if [[ "$PROJECT_TYPE" == "web" || "$PROJECT_TYPE" == "api" ]]; then
cat > package.json << 'PACKAGEEOF'
{
  "name": "${PROJECT_NAME}",
  "version": "0.1.0",
  "description": "${PROJECT_TYPE} project built with ClaudeBuilder",
  "main": "src/index.js",
  "scripts": {
    "start": "node src/index.js",
    "dev": "nodemon src/index.js",
    "test": "jest"
  },
  "dependencies": {
    "express": "^4.18.0"
  },
  "devDependencies": {
    "nodemon": "^3.0.0",
    "jest": "^29.0.0"
  }
}
PACKAGEEOF
fi

# Create .env.example
cat > .env.example << 'ENVEOF'
# Project Environment Configuration
NODE_ENV=development
PORT=3000

# Add your environment variables here
ENVEOF

# Create .gitignore
cat > .gitignore << 'GITEOF'
node_modules/
.env
.env.local
*.log
dist/
build/
.DS_Store
GITEOF

# Initial commit
git add .
git commit -m "feat: initial ${PROJECT_NAME} setup with ClaudeBuilder"

echo
echo -e "${GREEN}🎉 Project Created Successfully!${NC}"
echo "================================="
echo
echo -e "${BLUE}📁 Location:${NC} $PROJECT_DIR"
echo -e "${BLUE}🚀 Next Steps:${NC}"
echo "  1. cd $PROJECT_DIR"
echo "  2. claude --interactive"
echo "  3. Start building!"
