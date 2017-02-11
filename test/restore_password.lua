local exports = {}
local tap = require('tap')
local response = require('response')
local error = require('error')
local auth = require('auth')
local db = require('db')

local test = tap.test('fake_test')
local user_space = require('model.user').get_space()
local get_id_by_email = require('model.user').get_id_by_email

function exports.setup() end

function exports.before()
    local ok, code
    ok, code = auth.registration('test@test.ru')
    auth.complete_registration('test@test.ru', code, '123')
    ok, code = auth.registration('not_active@test.ru')
end

function exports.after()
    db.truncate_spaces()
end

function exports.teardown() end

function test_restore_password_success()
    local ok, token
    ok, token = auth.restore_password('test@test.ru')
    test:is(ok, true, 'test_restore_password_success password restored')
    test:isstring(token, 'test_restore_password_success token returned')
end

function test_complete_restore_password_success()
    local ok, token, user, expected
    ok, token = auth.restore_password('test@test.ru')
    ok, user = auth.complete_restore_password('test@test.ru', token, 'new_pwd')
    user['id'] = nil
    expected = {email = 'test@test.ru', is_active = true}
    test:is(ok, true, 'test_complete_restore_password_success password changed')
    test:is_deeply(user, expected, 'test_complete_restore_password_success user returned')
end

function test_complete_restore_password_and_auth_success()
    local ok, token, user, expected, session
    ok, token = auth.restore_password('test@test.ru')
    ok, user = auth.complete_restore_password('test@test.ru', token, 'new_pwd')
    ok, user = auth.auth('test@test.ru', 'new_pwd')
    session = user['session']
    user['id'] = nil
    user['session'] = nil
    expected = {email = 'test@test.ru', is_active = true}
    test:is(ok, true, 'test_complete_restore_password_and_auth_success user logged in')
    test:isstring(session, 'test_complete_restore_password_and_auth_success session returned')
    test:is_deeply(user, expected, 'test_complete_restore_password_and_auth_success user returned')
end

function test_restore_password_user_not_found()
    local got, expected
    got = {auth.restore_password('not_found@test.ru'), }
    expected = {response.error(error.USER_NOT_FOUND), }
    test:is_deeply(got, expected, 'test_restore_password_user_not_found')
end

function test_restore_password_user_not_active()
    local got, expected
    got = {auth.restore_password('not_active@test.ru'), }
    expected = {response.error(error.USER_NOT_ACTIVE), }
    test:is_deeply(got, expected, 'test_restore_password_user_not_active')
end

function test_complete_restore_password_user_not_found()
    local ok, token, id, session, got, expected
    ok, token = auth.restore_password('test@test.ru')

    -- TODO API METHOD FOR DELETING USER BY EMAIL ?
    id = get_id_by_email('test@test.ru')
    user_space:delete(id)

    got = {auth.complete_restore_password('test@test.ru', token, 'new_pwd'), }
    expected = {response.error(error.USER_NOT_FOUND), }
    test:is_deeply(got, expected, 'test_complete_restore_password_user_not_found')
end

function test_complete_restore_password_user_not_active()
    local ok, token, id, session, got, expected
    ok, token = auth.restore_password('test@test.ru')

    -- TODO API METHOD FOR BAN USER BY EMAIL ?
    id = get_id_by_email('test@test.ru')
    user_space:update(id, {{'=', 3, false}})

    got = {auth.complete_restore_password('test@test.ru', token, 'new_pwd'), }
    expected = {response.error(error.USER_NOT_ACTIVE), }
    test:is_deeply(got, expected, 'test_complete_restore_password_user_not_active')
end

function test_complete_restore_password_wrong_token()
    local ok, token, id, session, got, expected
    ok, token = auth.restore_password('test@test.ru')

    got = {auth.complete_restore_password('test@test.ru', 'wrong_password_token', 'new_pwd'), }
    expected = {response.error(error.WRONG_RESTORE_TOKEN), }
    test:is_deeply(got, expected, 'test_complete_restore_password_wrong_token')
end

function test_complete_restore_password_and_auth_with_old_password()
    local ok, token, user, got, expected
    ok, token = auth.restore_password('test@test.ru')
    ok, user = auth.complete_restore_password('test@test.ru', token, 'new_pwd')
    got = {auth.auth('test@test.ru', '123'), }
    expected = {response.error(error.WRONG_PASSWORD), }
    test:is_deeply(got, expected, 'test_complete_restore_password_and_auth_with_old_password')
end

exports.tests = {
    test_restore_password_success,
    test_complete_restore_password_success,
    test_complete_restore_password_and_auth_success,

    test_restore_password_user_not_found,
    test_restore_password_user_not_active,
    test_complete_restore_password_user_not_found,
    test_complete_restore_password_user_not_active,
    test_complete_restore_password_wrong_token,
    test_complete_restore_password_and_auth_with_old_password,
}

return exports