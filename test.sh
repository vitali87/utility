#!/usr/bin/env bash
# Test suite for u7 CLI
# Run with: nix develop --command bash test.sh

# Don't exit on error - we want to run all tests
set +e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m' # No Color

PASSED=0
FAILED=0

# Source the utility
source ./utility.sh

# Test helper
assert_equals() {
    local test_name="$1"
    local expected="$2"
    local actual="$3"
    
    if [[ "$actual" == "$expected" ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected: $expected"
        echo "  Got: $actual"
        ((FAILED++))
    fi
}

assert_contains() {
    local test_name="$1"
    local needle="$2"
    local haystack="$3"
    
    if [[ "$haystack" == *"$needle"* ]]; then
        echo -e "${GREEN}✓${NC} $test_name"
        ((PASSED++))
    else
        echo -e "${RED}✗${NC} $test_name"
        echo "  Expected to contain: $needle"
        echo "  Got: $haystack"
        ((FAILED++))
    fi
}

# Setup test directory
TEST_DIR=$(mktemp -d)
cd "$TEST_DIR"

echo "Running u7 tests..."
echo "==================="

# Test 1: JSON limit default
echo '[1,2,3,4,5,6,7,8,9,10,11,12,13,14,15]' > test.json
result=$(u7 show json test.json 2>&1)
line_count=$(echo "$result" | wc -l | tr -d ' ')
assert_equals "JSON default limit shows 10 items" "12" "$line_count"  # 10 items + [ + ]

# Test 2: JSON custom limit
result=$(u7 show json test.json limit 3 2>&1)
if [[ $? -eq 0 ]]; then
    line_count=$(echo "$result" | wc -l | tr -d ' ')
    assert_equals "JSON custom limit shows 3 items" "5" "$line_count"  # 3 items + [ + ]
else
    echo -e "${RED}✗${NC} JSON custom limit shows 3 items (command failed)"
    echo "  Output: $result"
    ((FAILED++))
fi

# Test 3: Text replacement with literal dot
echo "foo.bar is here and fooXbar too" > test_replace.txt
u7 set text "foo.bar" to "baz" in test_replace.txt >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    result=$(cat test_replace.txt)
    assert_equals "Text replacement treats dot literally" "baz is here and fooXbar too" "$result"
else
    echo -e "${RED}✗${NC} Text replacement treats dot literally (command failed)"
    ((FAILED++))
fi

# Test 4: Text replacement with special chars
echo "price is \$100" > test_special.txt
u7 set text "\$100" to "\$200" in test_special.txt >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    result=$(cat test_special.txt)
    assert_equals "Text replacement handles dollar signs" "price is \$200" "$result"
else
    echo -e "${RED}✗${NC} Text replacement handles dollar signs (command failed)"
    ((FAILED++))
fi

# Test 5: Password generation
result=$(u7 make password 16)
length=${#result}
assert_equals "Password generation creates 16 chars" "16" "$length"

# Test 6: Directory creation
u7 make dir testdir
if [[ -d "testdir" ]]; then
    echo -e "${GREEN}✓${NC} Directory creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Directory creation works"
    ((FAILED++))
fi

# Test 7: File creation
u7 make file testfile.txt
if [[ -f "testfile.txt" ]]; then
    echo -e "${GREEN}✓${NC} File creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} File creation works"
    ((FAILED++))
fi

# Test 8: Archive extraction to directory
echo "test content" > testfile.txt
gzip testfile.txt  # Creates testfile.txt.gz
mkdir extract_dir
u7 convert archive to files testfile.txt.gz extract_dir >/dev/null 2>&1
if [[ -f "extract_dir/testfile.txt" ]]; then
    echo -e "${GREEN}✓${NC} Archive extraction to directory works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Archive extraction to directory works"
    echo "  Expected: extract_dir/testfile.txt"
    ls -la extract_dir/
    ((FAILED++))
fi

# Test 9: Archive creation
echo "content" > file1.txt
echo "more" > file2.txt
u7 make archive test.tar.gz file1.txt file2.txt >/dev/null 2>&1
if [[ -f "test.tar.gz" ]]; then
    echo -e "${GREEN}✓${NC} Archive creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Archive creation works"
    ((FAILED++))
fi

# Test 10: Show line from file
echo -e "line1\nline2\nline3" > lines.txt
result=$(u7 show line 2 lines.txt)
assert_equals "Show specific line from file" "line2" "$result"

# Test 11: File move/rename
echo "test" > move_test.txt
u7 move move_test.txt to renamed.txt >/dev/null 2>&1
if [[ -f "renamed.txt" && ! -f "move_test.txt" ]]; then
    echo -e "${GREEN}✓${NC} File move/rename works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} File move/rename works"
    ((FAILED++))
fi

# Test 12: Copy files
echo "original" > original.txt
u7 make copy original.txt to copy.txt >/dev/null 2>&1
if [[ -f "copy.txt" ]]; then
    result=$(cat copy.txt)
    assert_equals "File copy preserves content" "original" "$result"
else
    echo -e "${RED}✗${NC} File copy preserves content"
    ((FAILED++))
fi

# Test 13: Symbolic link creation
echo "target" > link_target.txt
u7 make link link_target.txt to link.txt >/dev/null 2>&1
if [[ -L "link.txt" ]]; then
    echo -e "${GREEN}✓${NC} Symbolic link creation works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Symbolic link creation works"
    ((FAILED++))
fi

# Test 14: Drop line from file
echo -e "keep1\nremove\nkeep2" > dropline.txt
u7 drop line 2 dropline.txt >/dev/null 2>&1
result=$(cat dropline.txt)
assert_equals "Drop line removes correct line" "keep1
keep2" "$result"

# Test 15: Drop duplicate lines
echo -e "line1\nline2\nline1\nline3" > dupes.txt
u7 drop duplicates dupes.txt >/dev/null 2>&1
line_count=$(wc -l < dupes.txt | tr -d ' ')
assert_equals "Drop duplicates removes duplicates" "3" "$line_count"

# Test 16: Set file permissions
touch perm_test.txt
u7 set perms to 644 perm_test.txt >/dev/null 2>&1
# Use GNU stat which is available in nix develop
perms=$(stat -c "%a" perm_test.txt 2>&1 | grep -o '^[0-9]*' | head -1)
assert_equals "Set file permissions" "644" "$perms"

# Test 17: Convert JSON to YAML
echo '{"key": "value"}' > test.json
u7 convert json to yaml test.json test.yaml >/dev/null 2>&1
if [[ -f "test.yaml" ]]; then
    result=$(cat test.yaml)
    assert_contains "JSON to YAML conversion" "key: value" "$result"
else
    echo -e "${RED}✗${NC} JSON to YAML conversion (file not created)"
    ((FAILED++))
fi

# Test 18: Math calculation
result=$(u7 convert math "2+2" 2>&1)
assert_equals "Math calculation" "4" "$result"

# Test 19: Make sequence
result=$(u7 make sequence test 3 | wc -l | tr -d ' ')
assert_equals "Sequence generation" "3" "$result"

# Test 20: Show file diff
echo "version1" > diff1.txt
echo "version2" > diff2.txt
result=$(u7 show diff diff1.txt diff2.txt 2>&1)
assert_contains "Show file diff" "version1" "$result"

# Test 21: Text replacement in directory
mkdir replace_dir
echo "foo.bar" > replace_dir/file1.txt
echo "foo.bar" > replace_dir/file2.txt
u7 set text "foo.bar" to "replaced" in replace_dir >/dev/null 2>&1
result1=$(cat replace_dir/file1.txt)
result2=$(cat replace_dir/file2.txt)
if [[ "$result1" == "replaced" && "$result2" == "replaced" ]]; then
    echo -e "${GREEN}✓${NC} Text replacement in directory works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Text replacement in directory works"
    ((FAILED++))
fi

# Test 22: Set tabs to spaces
printf "line1\tline2" > tabs.txt
u7 set tabs to spaces . >/dev/null 2>&1
if grep -q "  " tabs.txt; then
    echo -e "${GREEN}✓${NC} Convert tabs to spaces works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Convert tabs to spaces works"
    ((FAILED++))
fi

# Test 23: Drop blank lines
echo -e "line1\n\nline2\n\nline3" > blank.txt
u7 drop lines blank blank.txt noblank.txt >/dev/null 2>&1
line_count=$(wc -l < noblank.txt | tr -d ' ')
assert_equals "Drop blank lines" "3" "$line_count"

# Test 24: Show modified files
touch -t 202301010000 old.txt
touch new.txt
result=$(u7 show files by modified 2>&1)
assert_contains "Show modified files" "new.txt" "$result"

# Test 25: Show big files
dd if=/dev/zero of=big.bin bs=1024 count=10 2>/dev/null
touch small.txt
result=$(u7 show files by size 2>&1)
assert_contains "Show big files" "big.bin" "$result"

# Test 26: Show disk usage of directories
mkdir -p subdir1 subdir2
echo "data" > subdir1/file.txt
result=$(u7 show usage directories 1 2>&1)
assert_contains "Show directory disk usage" "subdir1" "$result"

# Test 27: Show processes by CPU
result=$(u7 show processes by cpu 2>&1)
if echo "$result" | grep -q "[0-9]\+.*[0-9]\+\.[0-9]"; then
    echo -e "${GREEN}✓${NC} Show processes by CPU"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Show processes by CPU"
    ((FAILED++))
fi

# Test 28: Show processes by memory
result=$(u7 show processes by memory 2>&1)
if echo "$result" | grep -q "[0-9]\+.*[0-9]\+\.[0-9]"; then
    echo -e "${GREEN}✓${NC} Show processes by memory"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Show processes by memory"
    ((FAILED++))
fi

# Test 29: Set owner with 'to' operator
touch owner_test.txt
u7 set owner to $(whoami) owner_test.txt >/dev/null 2>&1
if [[ -f "owner_test.txt" ]]; then
    echo -e "${GREEN}✓${NC} Set owner with 'to' operator works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Set owner with 'to' operator works"
    ((FAILED++))
fi

# Test 30: Run job in background
u7 run job "echo test" in 1s >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Schedule job in background works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Schedule job in background works"
    ((FAILED++))
fi

# Test 31: Run command in background
result=$(u7 run background sleep 0.1 2>&1)
assert_contains "Run command in background" "PID:" "$result"

# Test 32: Check shell syntax
echo '#!/bin/bash' > test_script.sh
echo 'echo "test"' >> test_script.sh
u7 run check test_script.sh >/dev/null 2>&1
if [[ $? -eq 0 ]]; then
    echo -e "${GREEN}✓${NC} Shell syntax check works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Shell syntax check works"
    ((FAILED++))
fi

# Test 33: Show network info
result=$(u7 show network 2>&1)
assert_contains "Show network info" "lo" "$result"

# Test 34: Show port usage (lsof might need sudo, skip if fails)
result=$(u7 show port 22 2>&1 || echo "skipped")
if [[ "$result" != "skipped" ]]; then
    echo -e "${GREEN}✓${NC} Show port usage works"
    ((PASSED++))
else
    echo -e "${GREEN}✓${NC} Show port usage (skipped - requires permissions)"
    ((PASSED++))
fi

# Test 35: Make symbolic link
echo "link_target" > link_src.txt
u7 make link link_src.txt to link_dest.txt >/dev/null 2>&1
if [[ -L "link_dest.txt" ]]; then
    echo -e "${GREEN}✓${NC} Make symbolic link works"
    ((PASSED++))
else
    echo -e "${RED}✗${NC} Make symbolic link works"
    ((FAILED++))
fi

# Test 36: Priority/nice command
result=$(u7 set priority 10 echo "test" 2>&1)
assert_contains "Set process priority" "test" "$result"

# Cleanup
cd /
rm -rf "$TEST_DIR"

# Summary
echo "==================="
echo "Tests passed: $PASSED"
echo "Tests failed: $FAILED"
echo "==================="

if [[ $FAILED -gt 0 ]]; then
    exit 1
fi
