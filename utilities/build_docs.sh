echo "> Build doc pages..."
python ./mdhtml.py ../README.md -of ../index.html -tp . -t template.html

echo "> Build API pages..."
pushd .
cd ../documents
doxygen Doxyfile
popd
