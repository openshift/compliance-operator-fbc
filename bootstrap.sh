#! /bin/bash
set -x

for VERSION in ${OCP_VERSIONS}
do
    CONTAINERFILE="Containerfile-ocp5.in"
    if [[ "$VERSION" =~ ("4.12"|"4.13"|"4.14") ]]; then
            CONTAINERFILE="Containerfile-rhel-8.in"
    elif [[ "$VERSION" =~ ^4\. ]]; then
            CONTAINERFILE="Containerfile-rhel-9.in"
    fi

    opm migrate "registry.redhat.io/redhat/redhat-operator-index:v${VERSION}" "./catalog-migrate-${VERSION}"
    mkdir -p "catalog/v${VERSION}/compliance-operator"
    cp "${CONTAINERFILE}" "catalog/v${VERSION}/Containerfile"
    sed -i "s/OCP_VERSION/${VERSION}/g" "catalog/v${VERSION}/Containerfile"

    if [ -f "./catalog-migrate-${VERSION}/compliance-operator/catalog.json" ]; then
        opm alpha convert-template basic -o yaml "./catalog-migrate-${VERSION}/compliance-operator/catalog.json" > "catalog/v${VERSION}/catalog-template.yaml"
    else
        # After moving to Konflux, we need to bootstrap the catalog from the previous version
        PREV_MINOR=$(( ${VERSION##*.} - 1 ))
        PREV_VERSION="${VERSION%%.*}.${PREV_MINOR}"
        cp "catalog/v${PREV_VERSION}/catalog-template.yaml" "catalog/v${VERSION}/catalog-template.yaml"
    fi

    if [[ "$VERSION" =~ ("4.12"|"4.13"|"4.14"|"4.15"|"4.16") ]]; then
        opm alpha render-template basic -o yaml "catalog/v${VERSION}/catalog-template.yaml" > "catalog/v${VERSION}/compliance-operator/catalog.yaml"
    else
        opm alpha render-template basic -o yaml --migrate-level=bundle-object-to-csv-metadata "catalog/v${VERSION}/catalog-template.yaml" > "catalog/v${VERSION}/compliance-operator/catalog.yaml"
    fi

    echo "Building locally to ensure it works"
    podman build -t "co-fbc-${VERSION}" -f "catalog/v${VERSION}/Containerfile" "catalog/v${VERSION}/" && rm -rf "./catalog-migrate-${VERSION}"
done
