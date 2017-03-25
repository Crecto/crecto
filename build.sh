gitbook install && gitbook build
cp -R _book/* .
git clean -fx node_modules
git clean -fx _book
