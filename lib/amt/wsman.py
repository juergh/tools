#!/usr/bin/env python3
#
# Intel AMT wsman driver
# Inspired by OpenStack's Ironic AMT driver from ironic-staging-drivers.
#
# Copyright (C) 2018  Juerg Haefliger <juergh@gmail.com>
# Copyright (C) 2018  OpenStack Foundation
#
# Licensed under the Apache License, Version 2.0 (the "License"); you may
# not use this file except in compliance with the License. You may obtain
# a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS, WITHOUT
# WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the
# License for the specific language governing permissions and limitations
# under the License.

import subprocess
import time

import pywsman

from lib import utils

class WsManClient(object):
    """
    A pywsman client to connect to a target server
    """
    def __init__(self, host, username, password, wakeup_interval=60):
        protocol = "http"
        port = 16992

        if "://" in host:
            protocol, host = host.split("://")

        if ":" in host:
            host, port = host.split(":")
            port = int(port)

        self.last_query = 0
        self.wakeup_interval = wakeup_interval
        self.host = host
        self.client = pywsman.Client(host, port, "/wsman", protocol, username,
                                     password)

    def get(self, resource_uri, options=None):
        """
        Get info from the target server
        """
        if options is None:
            options = pywsman.ClientOptions()

        doc = self.client.get(options, resource_uri)
        self.last_query = time.time()
        if not doc:
            return -1, "[get] empty response", doc

        fault = utils.xml_find(doc, "http://www.w3.org/2003/05/soap-envelope",
                               "Fault")
        if fault:
            return -2, "[get] " + fault.text, doc
        return 0, "[get] success", doc

    def invoke(self, resource_uri, method, data=None, options=None):
        """
        Invoke a method on the target server
        """
        if options is None:
            options = pywsman.ClientOptions()

        if data is None:
            doc = self.client.invoke(options, resource_uri, method)
        else:
            doc = self.client.invoke(options, resource_uri, method, data)
        self.last_query = time.time()
        if not doc:
            return -1, "[invoke] empty response", doc

        retval = int(utils.xml_find(doc, resource_uri, "ReturnValue").text)
        if retval == 0:
            return 0, "[invoke] success", doc
        if retval == 2:
            return -retval, "[invoke] illegal request", doc
        return -retval, "[invoke] error (%s)" % retval, doc

    def wake_up(self):
        """
        Wake up the target server
        """
        now = time.time()
        if now - self.last_query > self.wakeup_interval:
            subprocess.run(["ping", "-i", "0.2", "-c", "5", self.host],
                           check=False, stdout=subprocess.PIPE)
            self.last_query = now
