# CodaMOSA

CodaMOSA 将大语言模型查询集成到基于搜索的 Python 单元测试生成算法中。当传统搜索算法陷入覆盖率平台期时，CodaMOSA 会调用大语言模型生成新的候选测试，从而帮助搜索继续提升代码覆盖率。

本项目对应论文：

> Caroline Lemieux, Jeevana Priya Inala, Shuvendu K. Lahiri, Siddhartha Sen. 2023. CODAMOSA: Escaping Coverage Plateaus in Test Generation with Pre-trained Large Language Models. In *Proceedings of the 45th International Conference on Software Engineering (ICSE '23)*.

本仓库基于 [Pynguin](https://github.com/se2p/pynguin) 0.19.0 实现，同时包含 Pynguin 的代码和 CodaMOSA 算法。如果只需要 Pynguin 的单元测试生成功能，建议使用上游 Pynguin 项目，因为它的维护频率更高。

本分支在原版 CodaMOSA 的基础上增加了以下能力：

- 支持 OpenAI 兼容的 `/v1/responses` 接口。
- 支持 OpenAI 兼容的 `/v1/chat/completions` 接口。
- 保留原有 `/v1/completions` 接口支持。
- 支持通过环境变量传入 API Key，避免把密钥写入源码或命令参数。
- 提供 `run-codamosa.sh` 一键构建和运行脚本。

## 主要实现文件

```text
pynguin/generation/algorithms/
└── codamosastrategy.py
    ├── 跟踪覆盖率平台期
    └── 调用大语言模型生成新的测试用例

pynguin/languagemodels/
├── astscoping.py
│   └── 定义包含 Pynguin VariableReference 的扩展 Python AST
├── functionplaceholderadder.py
│   └── 使用“??”占位符随机修改函数，目前 CodaMOSA 已不再使用
├── model.py
│   └── 大语言模型 API 请求和响应适配
└── outputfixers.py
    └── 将模型生成的代码规范化为接近 Pynguin 输出的 AST 重写器
```

## 快速开始（推荐）

### 1. 环境要求

- Git
- Docker Engine 或 Docker Desktop
- OpenAI 兼容的 API 端点、API Key 和模型 ID
- 需要分析的 Python 项目

先确认 Docker 服务已经运行：

```shell
docker info
```

### 2. 克隆仓库

```shell
git clone https://github.com/lyr339/codamosa.git
cd codamosa
```

### 3. 配置 API

在当前终端中设置以下环境变量：

```shell
export CODAMOSA_API_BASE_URL="https://你的-api-端点.example.com"
export CODAMOSA_API_KEY="你的-api-key"
export CODAMOSA_MODEL="你的模型-id"
```

例如：

```shell
export CODAMOSA_API_BASE_URL="https://example.com"
export CODAMOSA_API_KEY="sk-xxxxxxxx"
export CODAMOSA_MODEL="gpt-5.6-sol"
```

API 端点末尾带不带 `/v1` 均可，运行脚本会自动处理：

```text
https://example.com
https://example.com/v1
```

API Key 只会通过环境变量传入容器，不会保存到仓库。macOS 用户未设置 `CODAMOSA_API_KEY` 时，也可以先复制 API Key，脚本会临时读取剪贴板内容。

### 4. 准备待测试项目

待测试项目中建议包含以下文件之一：

```text
requirements.txt
package.txt
```

文件中填写项目运行所需的 Python 依赖。脚本会在临时 Docker 容器中安装这些依赖，不会修改宿主机 Python 环境。

假设项目结构如下：

```text
/work/calculator/
├── calculator.py
└── requirements.txt
```

其中 `calculator.py` 是需要生成测试的模块，对应模块名为 `calculator`。

对于包内模块：

```text
/work/my-project/
└── my_package/
    ├── __init__.py
    └── services.py
```

对应模块名为 `my_package.services`。

### 5. 一键运行

命令格式：

```shell
./run-codamosa.sh 项目绝对路径 Python模块名 [输出目录]
```

示例：

```shell
./run-codamosa.sh /work/calculator calculator
```

分析包内模块：

```shell
./run-codamosa.sh /work/my-project my_package.services
```

指定输出目录：

```shell
./run-codamosa.sh /work/calculator calculator /work/generated-tests
```

首次运行时，脚本会自动完成以下工作：

1. 构建 `codamosa-runner:latest` Docker 镜像。
2. 读取待测试项目的 `package.txt` 或 `requirements.txt`。
3. 在临时容器中安装项目依赖。
4. 通过配置的 API 端点调用大语言模型。
5. 运行 CodaMOSA 并生成测试文件和统计结果。
6. 在终端中输出结果目录。

未指定输出目录时，结果默认保存在：

```text
$HOME/Downloads/codamosa-output/
```

典型输出文件包括：

```text
test_<模块名>.py
test_<模块名>_failing.py
codex_generations.py
codamosa_timeline.csv
statistics.csv
```

## 可选配置

### 搜索时间

默认搜索时间为 120 秒，可以通过环境变量修改：

```shell
export CODAMOSA_MAX_SEARCH_TIME=300
```

### API 路径

默认使用 Responses API：

```shell
export CODAMOSA_API_PATH=/v1/responses
```

如果服务商提供 Chat Completions API：

```shell
export CODAMOSA_API_PATH=/v1/chat/completions
```

如果 `CODAMOSA_API_BASE_URL` 已经以 `/v1` 结尾，也可以设置：

```shell
export CODAMOSA_API_PATH=/responses
```

完整配置示例：

```shell
export CODAMOSA_API_BASE_URL="https://example.com/v1"
export CODAMOSA_API_KEY="sk-xxxxxxxx"
export CODAMOSA_MODEL="gpt-5.6-sol"
export CODAMOSA_API_PATH="/responses"
export CODAMOSA_MAX_SEARCH_TIME=300

./run-codamosa.sh /work/my-project my_package.services /work/generated-tests
```

## 手动使用 Docker

如果不使用一键脚本，可以先手动构建镜像：

```shell
docker build -t codamosa-runner -f docker/Dockerfile .
```

也可以显式指定目标平台：

```shell
docker build \
    -t codamosa-runner \
    -f docker/Dockerfile \
    --platform linux/amd64 \
    .
```

然后运行：

```shell
export CODAMOSA_API_KEY="你的-api-key"

docker run --rm \
    -e CODAMOSA_API_KEY \
    -v /待测试项目绝对路径:/input:ro \
    -v /输出目录绝对路径:/output \
    -v /包含-package.txt-的目录:/package:ro \
    codamosa-runner \
    --project-path /input \
    --module-name package.module \
    --output-path /output \
    --report-dir /output \
    --maximum-search-time 120 \
    --algorithm CODAMOSA \
    --assertion-generation NONE \
    --model-name MODEL_ID \
    --model-base-url API_BASE_URL \
    --model-relative-url /v1/responses \
    --include-partially-parsable True \
    --allow-expandable-cluster True \
    --uninterpreted-statements ONLY \
    -v
```

手动运行时，挂载到 `/package` 的目录中需要包含 `package.txt`。该文件采用与 `requirements.txt` 相同的格式，可以使用 `pipreqs` 辅助生成。

## 常见问题

### Docker 服务连接失败

先启动 Docker Engine 或 Docker Desktop，然后确认：

```shell
docker info
```

### API 返回 401

检查 API Key 是否正确设置：

```shell
test -n "$CODAMOSA_API_KEY" && echo "API Key 已设置"
```

### API 返回 404

确认服务端支持 `/v1/responses` 或 `/v1/chat/completions`，并检查：

```shell
echo "$CODAMOSA_API_BASE_URL"
echo "$CODAMOSA_API_PATH"
```

### 找不到 Python 模块

第二个参数需要填写 Python 导入路径，而不是文件路径：

```text
文件：my_package/services.py
模块：my_package.services
```

### 项目存在额外依赖

将依赖添加到待测试项目的 `requirements.txt` 或 `package.txt` 后重新运行。

## 复现实验

`replication` 目录中包含复现 ICSE '23 论文实验所需的文件，其中部分大文件使用 GitHub LFS 存储。完整克隆复现实验数据前，需要安装 [Git LFS](https://docs.github.com/zh/repositories/working-with-files/managing-large-files/installing-git-large-file-storage)：

```shell
git lfs install
git lfs pull
```

更多复现说明请查看 [`replication/README.md`](replication/README.md)。

## 开发

本项目使用 Python 3.10 和 [Poetry](https://python-poetry.org/) 进行依赖管理。

安装依赖：

```shell
poetry install
```

进入虚拟环境：

```shell
poetry shell
```

运行代码检查和测试：

```shell
make check
```

## 许可证

CodaMOSA 基于 Pynguin 0.19.0，该版本采用 LGPL-3.0 许可证。许可证副本位于 [`LICENSES/LGPL-3.0-or-later.txt`](LICENSES/LGPL-3.0-or-later.txt)。

CodaMOSA 新增或修改的文件采用 MIT 许可证，各文件头部会注明对应的 SPDX 许可证标识。Pynguin 0.30.0 及后续版本已改用 MIT 许可证。

## 贡献

本项目欢迎贡献和建议。向微软上游项目提交贡献时，通常需要签署贡献者许可协议（CLA），以确认贡献者拥有并授予相关代码的使用权。详情请查看 [Microsoft CLA](https://cla.opensource.microsoft.com)。

提交 Pull Request 后，CLA 机器人会自动检查签署状态并提供相应提示。通常只需签署一次。

本项目采用 [Microsoft 开源行为准则](https://opensource.microsoft.com/codeofconduct/)。更多信息请查看[行为准则常见问题](https://opensource.microsoft.com/codeofconduct/faq/)，或发送邮件至 [opencode@microsoft.com](mailto:opencode@microsoft.com)。

## 商标

本项目可能包含项目、产品或服务的商标及徽标。微软商标的使用需要遵循 [Microsoft 商标和品牌指南](https://www.microsoft.com/zh-cn/legal/intellectualproperty/trademarks/usage/general)。

修改后的版本不得造成微软赞助或认可该版本的误解。第三方商标及徽标的使用应遵循其各自的相关规定。
