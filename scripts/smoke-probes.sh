# scripts/smoke.sh 的一项一项探测，跟着插件走。没写的项会 FAIL 并给出写法，不会默认放行。
#
# 页面：web_assert 从标准输入读页面，命中的确是应用的真实页面时返回 0。
# 身份：identity_check 用应用自己的"当前用户"接口断言认出的是用户管理员。没有用户体系时写 IDENTITY_NA=1，
#       并在 SMOKE_NOTE 里写原因。dweb / web_get 是带用户会话的请求助手，可继续走应用自己的登录链。
# 工具：MCP_TOOL 写一个只读工具名（可带插件前缀），MCP_ARGS 是 JSON 参数；mcp_assert 从标准输入读调用结果。
#       要断言多个工具时改成写 mcp_check；调用前要备数据时写 before_mcp。
# 装之前要准备（如先配出口代理）：写 before_install。

# PhotoPrism：sso=none，应用自己不设登录（上游公共模式，访客即管理员），网页只经核心网关；清单没有 mcp。
SSO=none
MCP=0

web_assert() { grep -qi 'photoprism'; }   # 标准输入：应用页面

identity_check() { # 应用没有用户体系，"身份"就是只放行过了网关的请求：匿名请求被网关拒之门外，
  # 网页端口不开在局域网上，带用户会话进来的是应用自己的配置（公共模式生效）。
  local code ports page
  code="$(curl -sS --noproxy '*' -o /dev/null -w '%{http_code}' --max-time 60 "$SMOKE_WEB_URL/api/v1/config")" ||
    { echo "匿名请求失败：$code"; return 1; }
  [[ "$code" == "401" ]] || { echo "匿名 API 不是 401：$code"; return 1; }
  ports="$(docker inspect --format '{{json .HostConfig.PortBindings}}' \
    "wonton-$SMOKE_INSTANCE--$SMOKE_SLUG--photoprism" 2>/dev/null)" ||
    { echo "找不到插件容器"; return 1; }
  [[ "$ports" == "{}" ]] || { echo "插件容器发布了宿主端口：$ports"; return 1; }
  page="$(web_get /api/v1/config)" || { echo "带会话取 /api/v1/config 失败：$page"; return 1; }
  grep -q '"siteUrl"' <<<"$page" || { echo "应用配置没取到：$(head -c 150 <<<"$page")"; return 1; }
}
