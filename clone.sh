#!/bin/bash

mkdir .repo/local_manifests
git clone https://github.com/timangpopi1/android-device-xiaomi-rolex -b master device/xiaomi/rolex/
git clone https://github.com/Nick89786/android_vendor_xiaomi -b lineage-16.0 vendor/xiaomi/
git clone https://github.com/fadlyas07/kernel_xiaomi_msm8917_sd425 -b master kernel/xiaomi/rolex/
