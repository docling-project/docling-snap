 > [!NOTE]
> This is a fork of [HuggingSnap](https://github.com/huggingface/HuggingSnap) demo app.
> Building integration with [SmolDocling VLM](https://huggingface.co/ds4sd/SmolDocling-256M-preview) and implementing extra features related to document processing.
> This is an unstable draft implementation which will quickly evolve.

<h1 align="center" style="margin-top: 0;">Under Construction</h1>

<details>
<summary>HuggingSnap</summary>
<h1 align="center" style="margin-top: 0;">HuggingSnap 🤗</h1>

HuggingSnap is an iOS app that lets users quickly learn more about the places and objects around them. Just point your camera to do things like have text translated, summarized; identify plants and animals; and more.

HuggingSnap runs [SmolVLM2](https://huggingface.co/collections/HuggingFaceTB/smolvlm2-smallest-video-lm-ever-67ab6b5e84bf8aaa60cb17c7), a compact open multimodal model that accepts arbitrary sequences of image, videos, and text inputs to produce text outputs. 

Designed for efficiency, SmolVLM can answer questions about images, describe visual content, create stories grounded on multiple images, or function as a pure language model without visual inputs. Its lightweight architecture makes it suitable for on-device applications while maintaining strong performance on multimodal tasks.

The repository makes use of a modified version of [mlx-swift-examples](https://github.com/cyrilzakka/mlx-swift-examples) for VLM support.

## How to run

- Install from the [App Store](https://apps.apple.com/us/app/huggingsnap/id6742157364). You need an iPhone running iOS 18.

Or, to build the app yourself:
- Clone the repository
- Open `HuggingSnap.xcodeproj` in Xcode
- Run the app on a physical device

You'll need to change the bundle identifier and developer team to run the app on your device.
</details>
