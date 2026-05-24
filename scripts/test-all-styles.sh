#!/bin/bash
# Batch Test Script
# Renders regression fixtures, validates SVGs, and exports PNGs

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SKILL_DIR}/test-output"
TIMESTAMP=$(date +%Y%m%d_%H%M%S)

echo -e "${BLUE}=== Fireworks Tech Graph - Batch Test ===${NC}"
echo "Test directory: $TEST_DIR"
echo "Timestamp: $TIMESTAMP"
echo ""

# Create test directory
mkdir -p "$TEST_DIR"

# Test configuration
STYLES=(1 2 3 4 5 6 7)
STYLE_NAMES=("Flat Icon" "Dark Terminal" "Blueprint" "Notion Clean" "Glassmorphism" "Claude Official" "OpenAI Official")

# Summary counters
TOTAL=0
PASSED=0
FAILED=0
WARNINGS=0

FIXTURES_DIR="${SKILL_DIR}/fixtures"
REQUIRE_PNG="${REQUIRE_PNG:-1}"
RENDERER=""

if [ "$REQUIRE_PNG" != "0" ] && [ "$REQUIRE_PNG" != "1" ]; then
    echo -e "${RED}Error: REQUIRE_PNG must be 0 or 1 (got: ${REQUIRE_PNG})${NC}"
    exit 1
fi

if python3 -c "import cairosvg" 2>/dev/null; then
    RENDERER="cairosvg"
elif command -v rsvg-convert &> /dev/null; then
    RENDERER="rsvg-convert"
fi

if [ -n "$RENDERER" ]; then
    echo -e "${GREEN}PNG renderer: ${RENDERER}${NC}"
else
    WARNINGS=$((WARNINGS + 1))
    echo -e "${YELLOW}⚠ No PNG renderer detected (cairosvg / rsvg-convert)${NC}"
    if [ "$REQUIRE_PNG" = "1" ]; then
        echo -e "${YELLOW}⚠ PNG-required mode is enabled; tests without PNG output will fail${NC}"
    else
        echo -e "${YELLOW}⚠ SVG-only mode: set REQUIRE_PNG=1 to enforce PNG output${NC}"
    fi
fi

echo -e "${BLUE}Testing all styles...${NC}"
echo "----------------------------------------"

for i in "${!STYLES[@]}"; do
    STYLE="${STYLES[$i]}"
    STYLE_NAME="${STYLE_NAMES[$i]}"
    
    echo -e "\n${YELLOW}Style $STYLE: $STYLE_NAME${NC}"
    
    # Check if style reference exists
    STYLE_FILE=$(find "${SKILL_DIR}/references" -maxdepth 1 -type f -name "style-${STYLE}-*.md" | head -n 1)
    if [ -z "${STYLE_FILE:-}" ] || [ ! -f "$STYLE_FILE" ]; then
        echo -e "${RED}✗ Style file not found: $STYLE_FILE${NC}"
        FAILED=$((FAILED + 1))
        TOTAL=$((TOTAL + 1))
        continue
    fi
    
    echo -e "${GREEN}✓ Style file found${NC}"
    
    if [ ! -d "$FIXTURES_DIR" ]; then
        echo -e "${YELLOW}⚠ Fixtures directory not found: $FIXTURES_DIR${NC}"
        continue
    fi

    FIXTURE_FILES=$(find "$FIXTURES_DIR" -maxdepth 1 -type f -name "*.json" | sort || true)
    MATCHED_FIXTURES=()
    for FIXTURE in $FIXTURE_FILES; do
        FIXTURE_STYLE=$(python3 - "$FIXTURE" <<'PY'
import json
import sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(data.get("style", ""))
PY
)
        if [ "$FIXTURE_STYLE" = "$STYLE" ]; then
            MATCHED_FIXTURES+=("$FIXTURE")
        fi
    done

    if [ "${#MATCHED_FIXTURES[@]}" -eq 0 ]; then
        echo -e "${YELLOW}⚠ No regression fixtures found for style $STYLE${NC}"
        continue
    fi

    # Render, validate, and export each fixture
    for FIXTURE in "${MATCHED_FIXTURES[@]}"; do
        BASENAME=$(basename "$FIXTURE" .json)
        SVG_FILE="${TEST_DIR}/${BASENAME}_${TIMESTAMP}.svg"
        PNG_FILE="${TEST_DIR}/${BASENAME}_${TIMESTAMP}.png"
        TEMPLATE_TYPE=$(python3 - "$FIXTURE" <<'PY'
import json
import sys
from pathlib import Path
data = json.loads(Path(sys.argv[1]).read_text(encoding='utf-8'))
print(data.get("template_type", "architecture"))
PY
)

        echo -n "  Rendering $BASENAME... "
        TOTAL=$((TOTAL + 1))

        if python3 "${SKILL_DIR}/scripts/generate-from-template.py" "$TEMPLATE_TYPE" "$SVG_FILE" "$(cat "$FIXTURE")" > /dev/null 2>&1 \
            && "${SKILL_DIR}/scripts/validate-svg.sh" "$SVG_FILE" > /dev/null 2>&1; then
            PNG_OK=false

            if [ -n "$RENDERER" ]; then
                if [ "$RENDERER" = "cairosvg" ]; then
                    if python3 - "$SVG_FILE" "$PNG_FILE" <<'PY' >/dev/null 2>&1
import sys
import cairosvg

cairosvg.svg2png(url=sys.argv[1], write_to=sys.argv[2], scale=2)
PY
                    then
                        PNG_OK=true
                    fi
                elif [ "$RENDERER" = "rsvg-convert" ] && rsvg-convert -w 1920 "$SVG_FILE" -o "$PNG_FILE" 2>/dev/null; then
                    PNG_OK=true
                fi
            fi

            if [ "$PNG_OK" = true ] && [ -f "$PNG_FILE" ]; then
                PNG_SIZE=$(du -h "$PNG_FILE" | cut -f1)
                echo -e "${GREEN}✓ Pass${NC} (${PNG_SIZE})"
                PASSED=$((PASSED + 1))
            elif [ "$REQUIRE_PNG" = "1" ]; then
                if [ -z "$RENDERER" ]; then
                    echo -e "${RED}✗ Fail${NC} (PNG renderer missing)"
                    echo -e "    ${YELLOW}⚠ Install cairosvg: pip install cairosvg${NC}"
                else
                    echo -e "${RED}✗ Fail${NC} (PNG export failed via ${RENDERER})"
                fi
                FAILED=$((FAILED + 1))
            else
                WARNINGS=$((WARNINGS + 1))
                echo -e "${YELLOW}⚠ Pass (SVG only)${NC}"
                PASSED=$((PASSED + 1))
            fi
        else
            echo -e "${RED}✗ Fail${NC}"
            FAILED=$((FAILED + 1))
            if [ -f "$SVG_FILE" ]; then
                "${SKILL_DIR}/scripts/validate-svg.sh" "$SVG_FILE" 2>&1 | grep -E "✗|Error" | sed 's/^/    /' || true
            fi
        fi
    done
done

# Print summary
echo ""
echo "========================================"
echo -e "${BLUE}Test Summary${NC}"
echo "----------------------------------------"
echo "Total tests: $TOTAL"
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo -e "${YELLOW}Warnings: $WARNINGS${NC}"

if [ "$FAILED" -eq 0 ]; then
    echo -e "\n${GREEN}✓ All tests passed!${NC}"
    exit 0
else
    echo -e "\n${RED}✗ Some tests failed${NC}"
    exit 1
fi
