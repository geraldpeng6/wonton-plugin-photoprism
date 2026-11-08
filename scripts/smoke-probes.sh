# scripts/smoke.sh 的一项一项探测，跟着插件走。没写的项会 FAIL 并给出写法，不会默认放行。
# shellcheck shell=bash disable=SC2034
#
# 页面：web_assert 从标准输入读页面，命中的确是应用的真实页面时返回 0。
# 身份：identity_check 用应用自己的"当前用户"接口断言认出的是用户管理员。没有用户体系时写 IDENTITY_NA=1，
#       并在 SMOKE_NOTE 里写原因。dweb / web_get 是带用户会话的请求助手，可继续走应用自己的登录链。
# 工具：MCP_TOOL 写一个只读工具名（可带插件前缀），MCP_ARGS 是 JSON 参数；mcp_assert 从标准输入读调用结果。
#       要断言多个工具时改成写 mcp_check；调用前要备数据时写 before_mcp。
# 装之前要准备（如先配出口代理）：写 before_install。

# PhotoPrism：sso=none，应用自己不设登录（上游公共模式，访客即管理员），网页只经核心网关；清单没有 mcp。

web_assert() { grep -qi 'photoprism'; }   # 标准输入：应用页面

identity_check() { # 应用没有用户体系，"身份"就是只放行过了网关的请求：匿名请求被网关拒之门外，
  # 网页端口不开在局域网上，带用户会话进来的是应用自己的配置（公共模式生效）。
  local code ports page
  code="$(curl -sS --noproxy '*' -o /dev/null -w '%{http_code}' --max-time 60 "${SMOKE_WEB_URL%/}/api/v1/config")" ||
    { echo "匿名请求失败：$code"; return 1; }
  [[ "$code" == "401" ]] || { echo "匿名 API 不是 401：$code"; return 1; }
  ports="$(docker inspect --format '{{json .HostConfig.PortBindings}}' \
    "wonton-$SMOKE_INSTANCE--$SMOKE_SLUG--photoprism" 2>/dev/null)" ||
    { echo "找不到插件容器"; return 1; }
  # 没发布端口时 PortBindings 是 null（不是 {}）
  [[ "$ports" == "{}" || "$ports" == "null" ]] || { echo "插件容器发布了宿主端口：$ports"; return 1; }
  page="$(pp_api /api/v1/config)" || { echo "带会话取 /api/v1/config 失败：$page"; return 1; }
  grep -q '"siteUrl"' <<<"$page" || { echo "应用配置没取到：$(head -c 150 <<<"$page")"; return 1; }
}

probe_url() { printf '%s' "${SMOKE_WEB_URL%/}"; } # 套件给的 web_url 带尾斜杠，拼路径前归一化

pp_api() { # <路径> [curl 参数…]：带会话走网关调应用 API（网关把关匿名请求）
  local path="$1"
  shift
  curl -sS --noproxy '*' --max-time 120 --fail-with-body -b "${SMOKE_JAR:-}" "$@" "$(probe_url)$path"
}

marker_file() { # SMOKE_STATE 在套件里是状态目录（e2e 传的是标记文件本身），标记放对应路径
  if [[ -d "$SMOKE_STATE" ]]; then printf '%s' "$SMOKE_STATE/photoprism-marker"; else printf '%s' "${SMOKE_STATE}.marker"; fi
}

# 数据：相册库就是用户数据（索引库在插件数据目录，重装保留；照片本体在只读的 photos 共享目录）。
# data_write 往共享目录放一张内容带标记的小图（1×1 JPEG，应用只读不改），调应用自己的索引接口收进库，
# data_check 重装/升级后还能搜到它。
PP_JPEG_BASE64='/9j/4AAQSkZJRgABAQAAAQABAAD/2wBDAAoHBwgHBgoICAgLCgoLDhgQDg0NDh0VFhEYIx8lJCIfIiEmKzcvJik0KSEiMEExNDk7Pj4+JS5ESUM8SDc9Pjv/2wBDAQoLCw4NDhwQEBw7KCIoOzs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozs7Ozv/wAARCABAAEADASIAAhEBAxEB/8QAHwAAAQUBAQEBAQEAAAAAAAAAAAECAwQFBgcICQoL/8QAtRAAAgEDAwIEAwUFBAQAAAF9AQIDAAQRBRIhMUEGE1FhByJxFDKBkaEII0KxwRVS0fAkM2JyggkKFhcYGRolJicoKSo0NTY3ODk6Q0RFRkdISUpTVFVWV1hZWmNkZWZnaGlqc3R1dnd4eXqDhIWGh4iJipKTlJWWl5iZmqKjpKWmp6ipqrKztLW2t7i5usLDxMXGx8jJytLT1NXW19jZ2uHi4+Tl5ufo6erx8vP09fb3+Pn6/8QAHwEAAwEBAQEBAQEBAQAAAAAAAAECAwQFBgcICQoL/8QAtREAAgECBAQDBAcFBAQAAQJ3AAECAxEEBSExBhJBUQdhcRMiMoEIFEKRobHBCSMzUvAVYnLRChYkNOEl8RcYGRomJygpKjU2Nzg5OkNERUZHSElKU1RVVldYWVpjZGVmZ2hpanN0dXZ3eHl6goOEhYaHiImKkpOUlZaXmJmaoqOkpaanqKmqsrO0tba3uLm6wsPExcbHyMnK0tPU1dbX2Nna4uPk5ebn6Onq8vP09fb3+Pn6/9oADAMBAAIRAxEAPwC/RRRXx59sFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAFFFFABRRRQAUUUUAf//Z'

photoprism_share() { # 共享目录在宿主上的位置（核心把共享挂在状态目录的 data/shares 下）
  printf '%s/data/shares/photos' "$SMOKE_STATE"
}

data_write() {
  local marker file resp
  marker="$(od -An -N4 -tx4 /dev/urandom | tr -d ' \n')"
  file="wonton-smoke-$marker.jpg"
  mkdir -p "$(photoprism_share)" || { echo "建不了共享目录 $(photoprism_share)"; return 1; }
  printf '%s' "$PP_JPEG_BASE64" | base64 -d >"$(photoprism_share)/$file" || { echo "写不了标记图片"; return 1; }
  local idx
  idx="$(pp_api /api/v1/index -X POST)" || { echo "触发索引失败：$idx"; return 1; }
  echo "索引完成：$(head -c 200 <<<"$idx")"
  # 索引是后台跑的：轮询搜索直到标记图入库（最多 120 秒）。
  local i found=""
  for i in $(seq 1 60); do
    resp="$(pp_api "/api/v1/photos?count=200&q=wonton-smoke-$marker")" || { resp=""; sleep 2; continue; }
    found="$(jq -r --arg f "$file" '[.[] | select(.FileName == $f)][0].UID // empty' <<<"$resp" 2>/dev/null)" || found=""
    [[ -n "$found" ]] && break
    sleep 2
  done
  [[ -n "$found" ]] || { echo "索引 120 秒后还没收进标记图 $file：$(head -c 200 <<<"$resp")"; return 1; }
  jq -nc --arg f "$file" '{file:$f}' >"$(marker_file)"
}

data_check() {
  local file resp
  file="$(jq -r '.file // empty' "$(marker_file)" 2>/dev/null)" || true
  [[ -n "$file" ]] || { echo "没有 data_write 留下的标记"; return 1; }
  resp="$(pp_api "/api/v1/photos?count=200&q=wonton-smoke-${file#wonton-smoke-}")" ||
    { echo "搜索失败：$resp"; return 1; }
  jq -e --arg f "$file" 'any(.[]; .FileName == $f)' <<<"$resp" >/dev/null ||
    { echo "升级/重装后搜不到标记图 $file：$(head -c 300 <<<"$resp")"; return 1; }
}
