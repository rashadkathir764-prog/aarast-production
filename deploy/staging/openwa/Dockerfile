# Build only outside the deployment server. The caller must inspect/tag the
# reviewed local base ID before building (see README.md).
ARG OPENWA_BASE_IMAGE=aarast-openwa-reviewed-local:b7a52913-f8046e08@sha256:f8046e08d029cbb3433769f09034ffbea4e3d84c0ec78294f896cb1c9c9ff8b4
FROM ${OPENWA_BASE_IMAGE}
USER root
WORKDIR /app
COPY apply-message-key-fix.cjs message-key-contract.test.cjs /opt/aarast-delivery-contract/
RUN node /opt/aarast-delivery-contract/apply-message-key-fix.cjs /app \
    && node --test /opt/aarast-delivery-contract/message-key-contract.test.cjs
LABEL org.aarast.openwa.base-image-id="sha256:f8046e08d029cbb3433769f09034ffbea4e3d84c0ec78294f896cb1c9c9ff8b4" \
      org.aarast.openwa.base-revision="b7a52913ef1c32613ddd1b24f4bcb1ec912e4132" \
      org.aarast.openwa.delivery-contract="message-key-extraction-device-ack-required"
# Preserve the base entrypoint: it drops to the existing openwa UID itself.
# Starting that entrypoint as UID 996 would prevent its gosu transition.
USER root
