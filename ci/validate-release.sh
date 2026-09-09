#!/usr/bin/env bash
# Copyright 2026 InsightOS
# SPDX-License-Identifier: Apache-2.0
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     https://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -euo pipefail

# 只有规范版本标签可以触发发布，避免临时标签生成可下载制品。
if [[ ! "${CI_COMMIT_TAG:-}" =~ ^v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)(-(alpha|beta|rc)\.(0|[1-9][0-9]*))?$ ]]; then
  echo "不支持的发布标签：${CI_COMMIT_TAG:-<empty>}" >&2
  exit 1
fi

if [[ ! -s CHANGELOG.md ]]; then
  echo "CHANGELOG.md 不存在或为空" >&2
  exit 1
fi

tag_version="${CI_COMMIT_TAG#v}"
base_version="${tag_version%%-*}"
source_version="$(node -p "require('./package.json').version")"

lock_version="$(node -p "require('./package-lock.json').version")"
if [[ "$lock_version" != "$source_version" ]]; then
  echo "package-lock.json 版本 $lock_version 与 package.json $source_version 不一致" >&2
  exit 1
fi

if ! grep -Fq "## v${base_version}" CHANGELOG.md; then
  echo "CHANGELOG.md 缺少 v${base_version} 条目" >&2
  exit 1
fi

if [[ "$tag_version" == "$base_version" ]] && grep -Fq "## v${base_version}（开发中）" CHANGELOG.md; then
  echo "正式发布前必须移除 v${base_version} 的开发中标记" >&2
  exit 1
fi

# 预发布和正式发布都必须先在发布分支中把源码版本切换到完整标签版本。
# 例如 v0.2.0-rc.1 必须由源码版本 0.2.0-rc.1 生成，不能使用基础版本。
if [[ "$source_version" != "$tag_version" ]]; then
  echo "文档版本 $source_version 与标签 $tag_version 不一致" >&2
  exit 1
fi

echo "发布标签校验通过：$tag_version"
