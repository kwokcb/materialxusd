echo ">>>>>>>>>> Build Doc pages..."
python ./mdhtml.py ../README.md -of ../index.html -tp . -t template.html

echo ""
echo ">>>>>>>>>> Build API pages..."
pushd .
cd ../documents
doxygen Doxyfile
popd

echo ""
echo ">>>>>>>>>> Build Gallery pages..."
pushd .
cd ../tests/
source ./create_summary.sh
popd
