python ../utilities/create_image_path.py ./resources/Materials  -r "https://kwokcb.github.io/materialxusd/tests" -o usd_mtlx_image_gallery_internal.html
python ../utilities/create_image_path.py -hd "PhysicallyBased Materials USD Gallery" ./physically_based -o usd_physicallY_based_gallery_internal.html  -r "https://kwokcb.github.io/materialxusd/tests"
python ../utilities/create_image_path.py -hd "Unit Test Gallery" ./examples -o unit_test_gallery_internal.html  -r "https://kwokcb.github.io/materialxusd/tests"
pushd .
cd ../utilities/
python ./mdhtml.py ../tests/usd_physicallY_based_gallery_internal.html -of ../tests/usd_physicallY_based_gallery.html -tp .. -t template.html
python ./mdhtml.py ../tests/usd_mtlx_image_gallery_internal.html -of ../tests/usd_mtlx_image_gallery.html -tp .. -t template.html
python ./mdhtml.py ../tests/unit_test_gallery_internal.html -of ../tests/unit_test_gallery.html -tp .. -t template.html
popd