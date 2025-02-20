echo "Creating summary of the rendered test suites: glsl_vs_glslfx.html"
python ../utilities/tests_to_html.py  -d -o glsl_vs_glslfx.html -l2 glslfx
echo "Creating summary of the rendered test suites: glsl_vs_osl_glslfx.html"
python ../utilities/tests_to_html.py  -d -o glsl_vs_osl_glslfx.html -l2 osl -l3 glslfx
