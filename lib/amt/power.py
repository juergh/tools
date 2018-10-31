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

import time

import pywsman

from lib import utils
from lib.amt import wsman


AMT_POWER_MAP = {
    "on": 2,
    "cycle": 5,
    "off": 8,
    "reset": 10,
    "nmi": 11,
}

cim_schema_url = "http://schemas.dmtf.org/wbem/wscim/1/cim-schema/2/"
CIM_AssociatedPowerManagementService = (cim_schema_url +
                                        "CIM_AssociatedPowerManagementService")
CIM_PowerManagementService = (cim_schema_url +
                              "CIM_PowerManagementService")
CIM_ComputerSystem = cim_schema_url + "CIM_ComputerSystem"


def _request_power_state_change_input(state):
    """
    Generate a wsman xmldoc for requesting a power state change
    """
    method_input = "RequestPowerStateChange_INPUT"
    address = "http://schemas.xmlsoap.org/ws/2004/08/addressing"
    anonymous = address + "/role/anonymous"
    wsman = "http://schemas.dmtf.org/wbem/wsman/1/wsman.xsd"
    namespace = CIM_PowerManagementService

    doc = pywsman.XmlDoc(method_input)
    root = doc.root()
    root.set_ns(namespace)
    root.add(namespace, "PowerState", str(state))

    child = root.add(namespace, "ManagedElement", None)
    child.add(address, "Address", anonymous)

    grand_child = child.add(address, "ReferenceParameters", None)
    grand_child.add(wsman, "ResourceURI", CIM_ComputerSystem)

    g_grand_child = grand_child.add(wsman, "SelectorSet", None)

    g_g_grand_child = g_grand_child.add(wsman, "Selector", "ManagedSystem")
    g_g_grand_child.attr_add(wsman, "Name", "Name")

    return doc


def _get_power_state(client):
    """
    Get the power state from the wsman client
    """
    client.wake_up()

    namespace = CIM_AssociatedPowerManagementService
    errno, errstr, doc = client.get(namespace)
    if errno:
        return errstr

    power_state = int(utils.xml_find(doc, namespace, "PowerState").text)
    for state in AMT_POWER_MAP:
        if power_state == AMT_POWER_MAP[state]:
            return state
    return "unknown state (%s)" % power_state


def _set_power_state(client, state):
    """
    Set the power state of the wsman client
    """
    client.wake_up()

    options = pywsman.ClientOptions()
    options.add_selector("Name", "Intel(r) AMT Power Management Service")

    doc = _request_power_state_change_input(AMT_POWER_MAP[state])
    errno, errstr, retdoc = client.invoke(CIM_PowerManagementService,
                                          "RequestPowerStateChange", data=doc,
                                          options=options)
    if errno:
        print("failed to set power state (%s, %s)" % (errno, errstr))


class AMTPower(object):
    """
    Intel AMT power driver

    The power states as defined by AMT:
      2: Power On                   10: Master Bus Reset
      3: Sleep - Light              11: Diagnostic Interrupt (NMI)
      4: Sleep - Deep               12: Power Off - Soft Graceful
      5: Power Cycle (Off - Soft)   13: Power Off - Hard Graceful
      6: Power Off - Hard           14: Master Bus Reset Graceful
      7: Hibernate (Off - Soft)     15: Power Cycle (Off - Soft Graceful)
      8: Power Off - Soft           16: Power Cycle (Off - Hard Graceful)
      9: Power Cycle (Off - Hard)
    """
    def __init__(self, host, username, password):
        self.client = wsman.WsManClient(host, username, password)

    def get_power_state(self):
        """
        Get the power state from the host
        """
        return _get_power_state(self.client)

    def set_power_state(self, state, wait=False, timeout=30):
        """
        Set the power state of the host
        """
        if state not in AMT_POWER_MAP:
            return "invalid state (%s)" % state

        _set_power_state(self.client, state)
        if not wait:
            return ""

        now = time.time()
        while time.time() < (now + timeout):
            time.sleep(1)
            current_state = _get_power_state(self.client)
            if current_state == state:
                return state
        return "timeout (%s)" % current_state
