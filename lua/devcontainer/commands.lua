---@mod devcontainer.commands High level devcontainer commands
---@brief [[
---Provides functions representing high level devcontainer commands
---@brief ]]
local docker_compose = require("devcontainer.docker-compose")
local docker = require("devcontainer.docker")
local config_file = require("devcontainer.config_file.parse")
local log = require("devcontainer.internal.log")
local status = require("devcontainer.status")

local M = {}

local function get_nearest_devcontainer_config(callback)
	config_file.parse_nearest_devcontainer_config(function(err, data)
		if err then
			vim.notify("Parsing devcontainer config failed: " .. vim.inspect(err), vim.log.levels.ERROR)
			return
		end

		callback(config_file.fill_defaults(data))
	end)
end

local function generate_build_command_args(data)
	local build_args = nil
	if data.build.args then
		build_args = build_args or {}
		for k, v in pairs(data.build.args) do
			table.insert(build_args, "--build-arg")
			table.insert(build_args, k .. "=" .. v)
		end
	end
	if data.build.target then
		build_args = build_args or {}
		table.insert(build_args, "--target")
		table.insert(build_args, data.build.target)
	end
	if data.build.cacheFrom then
		build_args = build_args or {}
		if type(data.build.cacheFrom) == "string" then
			table.insert(build_args, "--cache-from")
			table.insert(build_args, data.build.cacheFrom)
		elseif type(data.build.cacheFrom) == "table" then
			for _, v in ipairs(data.build.cacheFrom) do
				table.insert(build_args, "--cache-from")
				table.insert(build_args, v)
			end
		end
	end
	return build_args
end

local function generate_common_run_command_args(data)
	local run_args = nil
	-- TODO: Add support for remoteEnv?
	if data.forwardPorts then
		run_args = run_args or {}
		for _, v in ipairs(data.forwardPorts) do
			table.insert(run_args, "--publish")
			table.insert(run_args, v)
		end
	end
	return run_args
end

local function generate_run_command_args(data)
	local run_args = generate_common_run_command_args(data)
	if data.containerUser then
		run_args = run_args or {}
		table.insert(run_args, "--user")
		table.insert(run_args, data.containerUser)
	end
	if data.workspaceFolder or data.workspaceMount then
		if data.workspaceMount == nil or data.workspaceFolder == nil then
			vim.notify("workspaceFolder and workspaceMount have to both be defined to be used!", vim.log.levels.WARN)
		else
			run_args = run_args or {}
			table.insert(run_args, "--workdir")
			table.insert(run_args, data.workspaceFolder)
			table.insert(run_args, "--mount")
			table.insert(run_args, data.workspaceMount)
		end
	end
	if data.mounts then
		run_args = run_args or {}
		for _, v in ipairs(data.mounts) do
			table.insert(run_args, "--mount")
			table.insert(run_args, v)
		end
	end
	if data.runArgs then
		run_args = run_args or {}
		vim.list_extend(run_args, data.runArgs)
	end
	if data.appPort then
		run_args = run_args or {}
		if type(data.appPort) == "table" then
			for _, v in ipairs(data.appPort) do
				table.insert(run_args, "--publish")
				table.insert(run_args, v)
			end
		else
			table.insert(run_args, "--publish")
			table.insert(run_args, data.appPort)
		end
	end
	return run_args
end

local function generate_compose_up_command_args(data)
	local run_args = nil
	if data.runServices then
		run_args = run_args or {}
		vim.list_extend(run_args, data.runServices)
	end
	return run_args
end

---Run docker-compose up from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_up()`
function M.compose_up(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully started services from " .. config.metadata.file_path)
		end

	get_nearest_devcontainer_config(function(data)
		if not data.dockerComposeFile then
			vim.notify(
				"Parsed devcontainer file ("
					.. data.metadata.file_path
					.. ") does not contain docker compose definition!",
				vim.log.levels.ERROR
			)
			return
		end

		docker_compose.up(data.dockerComposeFile, {
			args = generate_compose_up_command_args(data),
			on_success = function()
				on_success(data)
			end,
			on_fail = function()
				vim.notify("Docker compose up failed!", vim.log.levels.ERROR)
			end,
		})
	end)
end

---Run docker-compose down from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_down()`
function M.compose_down(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully stopped services from " .. config.metadata.file_path)
		end

	get_nearest_devcontainer_config(function(data)
		if not data.dockerComposeFile then
			vim.notify(
				"Parsed devcontainer file ("
					.. data.metadata.file_path
					.. ") does not contain docker compose definition!",
				vim.log.levels.ERROR
			)
			return
		end

		docker_compose.down(data.dockerComposeFile, {
			on_success = function()
				on_success(data)
			end,
			on_fail = function()
				vim.notify("Docker compose down failed!", vim.log.levels.ERROR)
			end,
		})
	end)
end

---Run docker-compose rm from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").compose_rm()`
function M.compose_rm(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully removed services from " .. config.metadata.file_path)
		end

	get_nearest_devcontainer_config(function(data)
		if not data.dockerComposeFile then
			vim.notify(
				"Parsed devcontainer file ("
					.. data.metadata.file_path
					.. ") does not contain docker compose definition!",
				vim.log.levels.ERROR
			)
			return
		end

		docker_compose.rm(data.dockerComposeFile, {
			on_success = function()
				on_success(data)
			end,
			on_fail = function()
				vim.notify("Docker compose rm failed!", vim.log.levels.ERROR)
			end,
		})
	end)
end

---Run docker build from nearest devcontainer.json file
---@param callback function|nil called on success - parsed devcontainer config and image id are passed to the callback
---@usage `require("devcontainer.commands").docker_build()`
function M.docker_build(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config, image_id)
			vim.notify("Successfully built docker image (" .. image_id .. ") from " .. config.build.dockerfile)
		end

	get_nearest_devcontainer_config(function(data)
		if not data.build.dockerfile then
			vim.notify(
				"Found devcontainer.json does not have dockerfile specified! - " .. data.metadata.file_path,
				vim.log.levels.ERROR
			)
			return
		end
		docker.build(data.build.dockerfile, data.build.context, {
			args = generate_build_command_args(data),
			on_success = function(image_id)
				on_success(data, image_id)
			end,
			on_fail = function()
				vim.notify("Building from " .. data.build.dockerfile .. " failed!", vim.log.levels.ERROR)
			end,
		})
	end)
end

---Run docker run from nearest devcontainer.json file
---@param callback function|nil called on success - devcontainer config and container id are passed to the callback
---@usage `require("devcontainer.commands").docker_image_run()`
function M.docker_image_run(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config, container_id)
			vim.notify(
				"Successfully started image ("
					.. config.image
					.. ") from "
					.. config.metadata.file_path(" - container id: ")
					.. container_id
			)
		end

	get_nearest_devcontainer_config(function(data)
		if not data.image then
			vim.notify(
				"Found devcontainer.json does not have image specified! - " .. data.metadata.file_path,
				vim.log.levels.ERROR
			)
			return
		end
		docker.run(data.image, {
			args = generate_run_command_args(data),
			on_success = function(container_id)
				on_success(data, container_id)
			end,
			on_fail = function()
				vim.notify("Running image " .. data.image .. " failed!", vim.log.levels.ERROR)
			end,
		})
	end)
end

local function spawn_docker_build_and_run(data, on_success, add_neovim)
	docker.build(data.build.dockerfile, data.build.context, {
		args = generate_build_command_args(data),
		add_neovim = add_neovim,
		on_success = function(image_id)
			docker.run(image_id, {
				args = generate_run_command_args(data),
				tty = add_neovim,
				-- TODO: Potentially add in the future for better compatibility
				-- or (data.overrideCommand and {
				-- "/bin/sh",
				-- "-c",
				-- "'while sleep 1000; do :; done'",
				-- })
				command = (add_neovim and "nvim") or nil,
				on_success = function(container_id)
					on_success(data, image_id, container_id)
				end,
				on_fail = function()
					vim.notify("Running built image (" .. image_id .. ") failed!", vim.log.levels.ERROR)
				end,
			})
		end,
		on_fail = function()
			vim.notify("Building image from (" .. data.build.dockerfile .. ") failed!", vim.log.levels.ERROR)
		end,
	})
end

local function execute_docker_build_and_run(callback, add_neovim)
	local on_success = callback
		or function(config, image_id, container_id)
			vim.notify(
				"Successfully started image ("
					.. image_id
					.. ") from "
					.. config.metadata.file_path
					.. " - container id: "
					.. container_id
			)
		end

	get_nearest_devcontainer_config(function(data)
		if not data.build.dockerfile then
			vim.notify(
				"Found devcontainer.json does not have dockerfile specified! - " .. data.metadata.file_path,
				vim.log.levels.ERROR
			)
			return
		end
		spawn_docker_build_and_run(data, on_success, add_neovim)
	end)
end

---Run docker run from nearest devcontainer.json file, building before that
---@param callback function|nil called on success - devcontainer config and container id are passed to the callback
---@usage `require("devcontainer.commands").docker_build_and_run()`
function M.docker_build_and_run(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	execute_docker_build_and_run(callback, false)
end

---Run docker run from nearest devcontainer.json file, building before that
---And then attach to the container with neovim added
---@param callback function|nil called on success - devcontainer config and container id are passed to the callback
---@usage `require("devcontainer.commands").docker_build_run_and_attach()`
function M.docker_build_run_and_attach(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	execute_docker_build_and_run(callback, true)
end

---Parses devcontainer.json and starts whatever is defined there
---Looks for dockerComposeFile first
---Then it looks for dockerfile
---And last it looks for image
---@param callback function|nil called on success - devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").start_auto()`
function M.start_auto(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully started from " .. config.metadata.file_path)
		end

	get_nearest_devcontainer_config(function(data)
		if data.dockerComposeFile then
			vim.notify("Found docker compose file definition. Running docker compose up...")
			docker_compose.up(data.dockerComposeFile, {
				args = generate_compose_up_command_args(data),
				on_success = function()
					on_success(data)
				end,
				on_fail = function()
					vim.notify("Docker compose up failed!", vim.log.levels.ERROR)
				end,
			})
			return
		end

		if data.build.dockerfile then
			vim.notify("Found dockerfile definition. Running docker build and run...")
			spawn_docker_build_and_run(data, on_success, false)
			return
		end

		if data.image then
			vim.notify("Found image definition. Running docker run...")
			docker.run(data.image, {
				args = generate_run_command_args(data),
				on_success = function(_)
					on_success(data)
				end,
				on_fail = function()
					vim.notify("Running image " .. data.image .. " failed!", vim.log.levels.ERROR)
				end,
			})
			return
		end
	end)
end

---Parses devcontainer.json and stops whatever is defined there
---Looks for dockerComposeFile first
---Then it looks for dockerfile
---And last it looks for image
---@param callback function|nil called on success - devcontainer config is passed to the callback
---@usage `require("devcontainer.commands").stop_auto()`
function M.stop_auto(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback
		or function(config)
			vim.notify("Successfully stopped services from " .. config.metadata.file_path)
		end

	get_nearest_devcontainer_config(function(data)
		if data.dockerComposeFile then
			vim.notify("Found docker compose file definition. Running docker compose down...")
			docker_compose.down(data.dockerComposeFile, {
				on_success = function()
					on_success(data)
				end,
				on_fail = function()
					vim.notify("Docker compose down failed!", vim.log.levels.ERROR)
				end,
			})
			return
		end

		if data.build.dockerfile then
			vim.notify("Found dockerfile definition. Running docker container stop...")
			local image = status.find_image({ source_dockerfile = data.build.dockerfile })
			if image then
				local container = status.find_container({ image_id = image.image_id })
				docker.container_stop({ container.container_id }, {
					on_success = function()
						on_success(data)
					end,
					on_fail = function()
						vim.notify("Docker container stop failed!", vim.log.levels.ERROR)
					end,
				})
			else
				vim.notify("Can't find container to stop", vim.log.levels.ERROR)
			end
			return
		end

		if data.image then
			vim.notify("Found image definition. Running docker container stop...")
			local container = status.find_container({ image_id = data.image })
			docker.container_stop({ container.container_id }, {
				on_success = function()
					on_success(data)
				end,
				on_fail = function()
					vim.notify("Docker container stop failed!", vim.log.levels.ERROR)
				end,
			})
			return
		end
	end)
end

---Stops everything started with devcontainer plugin
---@param callback function|nil called on success
---@usage `require("devcontainer.commands").stop_all()`
function M.stop_all(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback or function()
		vim.notify("Successfully stopped all services!")
	end
	local success_count = 0
	local success_wrapper = function()
		success_count = success_count + 1
		if success_count == 2 then
			on_success()
		end
	end

	local all_status = status.get_status()
	local containers_to_stop = vim.tbl_map(function(cstatus)
		return cstatus.container_id
	end, all_status.running_containers)
	if #containers_to_stop > 0 then
		docker.container_stop(containers_to_stop, {
			on_success = success_wrapper,
			on_fail = function()
				vim.notify("Docker container stop failed!", vim.log.levels.ERROR)
			end,
		})
	else
		success_wrapper()
	end
	local compose_services_to_stop = vim.tbl_map(function(cstatus)
		return cstatus.file
	end, all_status.compose_services)
	if #compose_services_to_stop > 0 then
		docker_compose.down(compose_services_to_stop, {
			on_success = success_wrapper,
			on_fail = function()
				vim.notify("Docker compose down failed!", vim.log.levels.ERROR)
			end,
		})
	else
		success_wrapper()
	end
end

---Removes everything started with devcontainer plugin
---@param callback function|nil called on success
---@usage `require("devcontainer.commands").remove_all()`
function M.remove_all(callback)
	vim.validate({
		callback = { callback, { "function", "nil" } },
	})

	local on_success = callback or function()
		vim.notify("Successfully removed all containers and images!")
	end

	local all_status = status.get_status()
	local images_to_remove = vim.tbl_map(function(cstatus)
		return cstatus.image_id
	end, all_status.images_built)
	local containers_to_remove = vim.tbl_map(function(cstatus)
		return cstatus.container_id
	end, all_status.running_containers)
	local compose_services_to_remove = vim.tbl_map(function(cstatus)
		return cstatus.file
	end, all_status.compose_services)

	local success_count = 0
	local success_wrapper
	success_wrapper = function()
		success_count = success_count + 1
		if success_count == 2 then
			if #images_to_remove > 0 then
				docker.image_rm(images_to_remove, {
					force = true,
					on_success = success_wrapper,
					on_fail = function()
						vim.notify("Docker image remove failed!", vim.log.levels.ERROR)
					end,
				})
			else
				success_wrapper()
			end
		end
		if success_count == 3 then
			on_success()
		end
	end
	if #containers_to_remove > 0 then
		docker.container_rm(containers_to_remove, {
			force = true,
			on_success = success_wrapper,
			on_fail = function()
				vim.notify("Docker container remove failed!", vim.log.levels.ERROR)
			end,
		})
	else
		success_wrapper()
	end
	if #compose_services_to_remove > 0 then
		docker_compose.rm(compose_services_to_remove, {
			on_success = success_wrapper,
			on_fail = function()
				vim.notify("Docker compose remove failed!", vim.log.levels.ERROR)
			end,
		})
	else
		success_wrapper()
	end
end

---Opens log file in a new buffer
---@usage `require("devcontainer.commands").open_logs()`
function M.open_logs()
	vim.cmd("edit " .. log.logfile)
end

log.wrap(M)
return M