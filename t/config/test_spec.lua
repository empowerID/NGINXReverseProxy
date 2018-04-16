local utils = require"test_utils"
local sh, stdout, stderr, sleep, sh_ex = utils.sh, utils.stdout, utils.stderr, utils.sleep, utils.sh_ex
local pl_path = require"pl.path"
local pl_tmpname = pl_path.tmpname
local pl_file = require"pl.file"


local git_root = os.getenv"GIT_ROOT"
package.path = package.path ..";" .. git_root .. "/lib/?.lua"
local config_module = require"empowerid.config"
local tprint = require"empowerid.tprint"
local checkStaticAbacRights = config_module.checkStaticAbacRights

test("test config.new() - config builder", function()

    local config = assert(config_module.new())

    local providesIds = config({
        {
            [1] = 1093,
            [2] = "F1B420D1-B6B9-4C92-B383-4AA4A6CB8643",
            [3] = "RickTest1001",
            [4] = "F1B420D1-B6B9-4C92-B383-4AA4A6CB8643",
            [5] = "EmpowerID",
            [6] = "https://sso.empoweriam.com/moduletest/bb083b0b-902f-40b9-a0a4-2c627dfc3f9d",
            [7] = 1129,
        },
        {
            [1] = 1094,
            [2] = "068CD819-655D-4414-A976-3CCF7377A2E5",
            [3] = "andysbeans",
            [4] = "068CD819-655D-4414-A976-3CCF7377A2E5",
            [5] = "EmpowerID",
            [6] = "https://sso.empoweriam.com:8080/moduletest/6ac010a1-4ee7-4ab2-b6bb-47c3a0e45c07/e5b696a0-fda0-4c4e-81a9-b75bafcbad58",
            [7] = 1130,
        },
        {
            [1] = 1095,
            [2] = "068CD819-655D-4414-A976-3CCF7377A2E6",
            [3] = "andysbeans",
            [4] = "068CD819-655D-4414-A976-3CCF7377A2E6",
            [5] = "EmpowerID",
            [6] = "http://empoweriam.com",
            [7] = 1131,
        },
        {
            [1] = 1100,
            [2] = "9BCA8113-B6E1-40EC-B6AA-D646EC9EF7BA",
            [3] = "@SUM(1+1)*cmd|' /C calc'!A0",
            [4] = "9BCA8113-B6E1-40EC-B6AA-D646EC9EF7BA",
            [5] = "EmpowerID",
            [6] = "asdas/a814f9c3-7ff9-4088-a2ad-45a57d5094be/26b23194-e3ff-4663-9b5f-475b4689dfe6/357f3305-5a09-457e-93e3-c461dd0f0dfd/ee49ddd1-dcc8-4b2d-a752-0f0f66d5080a",
            [7] = 1120,
        },
    },{
        ["068CD819-655D-4414-A976-3CCF7377A2E5"] = true,
        ["F1B420D1-B6B9-4C92-B383-4AA4A6CB8643"] = true,
        ["068CD819-655D-4414-A976-3CCF7377A2E6"] = true,
    })

    assert(providesIds:find("1094"))
    assert(providesIds:find("1093"))

    local res = config()
    assert(res.size == 3)
    assert(res["https://sso.empoweriam.com:443"])
    assert(res["https://sso.empoweriam.com:8080"])

    local appIds = config({
        {
            [1] = 16393,
            [2] = 6,
            [3] = 1093,
            [4] = "userdata: NULL",
            [5] = "userdata: NULL",
            [6] = "false",
            [7] = "1",
            [8] = "false",
            [9] = "userdata: NULL",
        },
        {
            [1] = 16394,
            [2] = 6,
            [3] = 1094,
            [4] = "userdata: NULL",
            [5] = "userdata: NULL",
            [6] = "false",
            [7] = "111111",
            [8] = "false",
            [9] = "sso.empoweriam.com",
        },
        {
            [1] = 16395,
            [2] = 6,
            [3] = 1095,
            [4] = "userdata: NULL",
            [5] = "userdata: NULL",
            [6] = "true",
            [7] = "111111",
            [8] = "false",
            [9] = "sso.empoweriam.com",
        },

    })

    assert(appIds:find("16393"))
    assert(appIds:find("16394"))

    local res = config()
    assert(res["https://sso.empoweriam.com:443"].app)
    assert(res["https://sso.empoweriam.com:8080"].app)
    assert(res["http://empoweriam.com:80"].app)

    config{
        {
            [1] = 3876846,
            [2] = 16393,
            [3] = "",
            [4] = "/test",
            [5] = "",
            [6] = "20c75f42-0b3a-4c3e-8cca-a10aebb43b1c",
            [7] = "false",
        },
        {
            [1] = 3876850,
            [2] = 16393,
            [3] = "",
            [4] = "",
            [5] = "^/regexp",
            [6] = "20c75f42-0b3a-4c3e-8cca-a10aebb43b1c",
            [7] = "true",
        },
    }

    local res = config()

    config{
        {
            [1] = 3876846,
            [2] = 1,
        },
        {
            [1] = 3876850,
            [2] = 1,
        },
        {
            [1] = 3877464,
            [2] = 1,
        },
        {
            [1] = 3876846,
            [2] = 2,
        },
        {
            [1] = 3876850,
            [2] = 2,
        },
        {
            [1] = 3877464,
            [2] = 2,
        },
        {
            [1] = 3876846,
            [2] = 10,
        },
        {
            [1] = 3876850,
            [2] = 10,
        },
        {
            [1] = 3877464,
            [2] = 10,
        },
        {
            [1] = 3876846,
            [2] = 11,
        },
    }

    local api_config = config()

    local c1 = config_module.open(api_config, "https://sso.empoweriam.com")

    assert(c1:doesProtectedPathsExists())
    assert.is_false(c1:allowNoAuthForNonProtectedPaths())

    local id1, mustDoLiveCheck = c1:isProtectedPath("/test")
    assert(id1)
    assert.is_false(mustDoLiveCheck)
    assert(checkStaticAbacRights(api_config, id1, 1))
    assert.is_false(checkStaticAbacRights(api_config, id1, 777))

    local id11 = c1:isProtectedPath("/testing")
    assert(id11)
    local id12 = c1:isProtectedPath("/bla-bla")
    assert.is_false(id12)

    local id2, mustDoLiveCheck = c1:isProtectedPath("/regexp")
    assert(id2)
    assert(mustDoLiveCheck)
    assert.is_false(c1:isProtectedPath("/bla-bla/regexp"))


    local c2 = config_module.open(api_config, "https://sso.empoweriam.com:8080")
    assert.is_false(c2:doesProtectedPathsExists())
    assert.is_false(c2:allowNoAuthForNonProtectedPaths())

    local c3 = config_module.open(api_config, "http://empoweriam.com:80")
    assert.is_false(c3:doesProtectedPathsExists())
    assert(c3:allowNoAuthForNonProtectedPaths())

end)
