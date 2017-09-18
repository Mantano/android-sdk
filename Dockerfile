FROM ubuntu:zesty

MAINTAINER Jean-Marie Geffroy <jmg@mantano.com>

# Install Git and dependencies
RUN dpkg --add-architecture i386 \
 && apt-get update \
 && apt-get install -y file git curl zip libncurses5:i386 libstdc++6:i386 zlib1g:i386 \
 && apt-get clean \
 && rm -rf /var/lib/apt/lists /var/cache/apt

# Install Java
RUN apt-get update && apt-get install -y libc6-dev-i386 lib32z1 openjdk-8-jre

# Install rsvg-convert
RUN apt-get update && apt-get install -y librsvg2-bin
RUN ls /usr/bin
RUN which rsvg-convert

# Install wget
RUN  apt-get update \
  && apt-get install -y wget \
  && rm -rf /var/lib/apt/lists/*

RUN  apt-get update \
  && apt-get install -y build-essential \
  && apt-get install -y autoconf

# ZLib (for Ruby)
RUN  apt-get update \
 && apt-get install zlib1g-dev

# OpenSSL
RUN  apt-get update \
 && apt-get install -y libssl-dev

# Install Ruby (Source: https://raw.githubusercontent.com/docker-library/ruby/135c84979b1401a6963e75f3c95161bfe5be2336/2.4/stretch/Dockerfile)

##FROM buildpack-deps:stretch

# skip installing gem documentation
RUN mkdir -p /usr/local/etc \
	&& { \
		echo 'install: --no-document'; \
		echo 'update: --no-document'; \
	} >> /usr/local/etc/gemrc

ENV RUBY_MAJOR 2.4
ENV RUBY_VERSION 2.4.1
ENV RUBY_DOWNLOAD_SHA256 4fc8a9992de3e90191de369270ea4b6c1b171b7941743614cc50822ddc1fe654
ENV RUBYGEMS_VERSION 2.6.13

# some of ruby's build scripts are written in ruby
#   we purge system ruby later to make sure our final image uses what we just built
RUN set -ex \
	\
	&& buildDeps=' \
		bison \
		dpkg-dev \
		libgdbm-dev \
		ruby \
	' \
	&& apt-get update \
	&& apt-get install -y --no-install-recommends $buildDeps \
	&& rm -rf /var/lib/apt/lists/* \
	\
	&& wget -O ruby.tar.xz "https://cache.ruby-lang.org/pub/ruby/${RUBY_MAJOR%-rc}/ruby-$RUBY_VERSION.tar.xz" \
	&& echo "$RUBY_DOWNLOAD_SHA256 *ruby.tar.xz" | sha256sum -c - \
	\
	&& mkdir -p /usr/src/ruby \
	&& tar -xJf ruby.tar.xz -C /usr/src/ruby --strip-components=1 \
	&& rm ruby.tar.xz \
	\
	&& cd /usr/src/ruby \
	\
# hack in "ENABLE_PATH_CHECK" disabling to suppress:
#   warning: Insecure world writable dir
	&& { \
		echo '#define ENABLE_PATH_CHECK 0'; \
		echo; \
		cat file.c; \
	} > file.c.new \
	&& mv file.c.new file.c \
	\
	&& autoconf \
	&& gnuArch="$(dpkg-architecture --query DEB_BUILD_GNU_TYPE)" \
	&& ./configure \
		--build="$gnuArch" \
		--disable-install-doc \
		--enable-shared \
	&& make -j "$(nproc)" \
	&& make install \
	\
	&& apt-get purge -y --auto-remove $buildDeps \
	&& cd / \
	&& rm -r /usr/src/ruby \
	\
	&& gem update --system "$RUBYGEMS_VERSION"

ENV BUNDLER_VERSION 1.15.4

RUN gem install bundler --version "$BUNDLER_VERSION"

# install things globally, for great justice
# and don't create ".bundle" in all our apps
ENV GEM_HOME /usr/local/bundle
ENV BUNDLE_PATH="$GEM_HOME" \
	BUNDLE_BIN="$GEM_HOME/bin" \
	BUNDLE_SILENCE_ROOT_WARNING=1 \
	BUNDLE_APP_CONFIG="$GEM_HOME"
ENV PATH $BUNDLE_BIN:$PATH
RUN mkdir -p "$GEM_HOME" "$BUNDLE_BIN" \
	&& chmod 777 "$GEM_HOME" "$BUNDLE_BIN"

CMD [ "irb" ]
########################

# Create a non-root user
RUN useradd -m mantano
USER mantano
WORKDIR /home/mantano

# Set up environment variables
# SDK_URL="https://dl.google.com/android/repository/platform-26_r01.zip" \
ENV ANDROID_HOME="/home/mantano/android-sdk-linux" \
    SDK_URL=https://dl.google.com/android/repository/sdk-tools-linux-3859397.zip \
    GRADLE_URL="https://services.gradle.org/distributions/gradle-4.1-all.zip"

# Install Gradle
RUN wget $GRADLE_URL -O gradle.zip \
 && unzip gradle.zip \
 && mv gradle-4.1 gradle \
 && rm gradle.zip \
 && mkdir .gradle

# Download Android SDK
#  && curl -o sdk.zip $SDK_URL
#  && wget  -q --show-progress $SDK_URL ‐O sdk.zip

RUN mkdir "$ANDROID_HOME" .android \
 && cd "$ANDROID_HOME" \
 && curl -o sdk.zip $SDK_URL

RUN cd "$ANDROID_HOME" \
 && unzip sdk.zip \
 && rm sdk.zip

RUN cd "$ANDROID_HOME" \
 && mkdir licenses \
 && echo -n 8933bad161af4178b1185d1a37fbf41ea5269c55 \
        > licenses/android-sdk-license

ENV PATH="/home/mantano/gradle/bin:${ANDROID_HOME}/tools:${ANDROID_HOME}/platform-tools:${PATH}"

# Install Android SDK components

# License Id: android-sdk-license-ed0d0a5b
# ENV ANDROID_COMPONENTS platform-tools,build-tools-26.0.1,android-15,android-19,android-24,android-25,android-26

# License Id: android-sdk-license-5be876d5
# ENV GOOGLE_COMPONENTS extra-android-m2repository,extra-google-m2repository
# RUN echo y | android update sdk --no-ui --all --filter "${ANDROID_COMPONENTS}" ;
#  &&  echo y | android update sdk --no-ui --all --filter "${GOOGLE_COMPONENTS}"

RUN ruby -v
RUN echo $PATH
RUN ls /home/mantano/android-sdk-linux/
RUN ls /home/mantano/android-sdk-linux/tools/
