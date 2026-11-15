
## =====================================================
## Nexys A7-100T Temperature Sensor Project
## Top module: temperature_top
## =====================================================

## 1. 100 MHz clock
set_property -dict { PACKAGE_PIN E3 IOSTANDARD LVCMOS33 } [get_ports {clk}]
create_clock -add -name sys_clk_pin -period 10.00 -waveform {0 5} [get_ports {clk}]

## 2. Reset button: center button, active-high
set_property -dict { PACKAGE_PIN N17 IOSTANDARD LVCMOS33 } [get_ports {rst}]

## 3. ADT7420 temperature sensor I2C
set_property -dict { PACKAGE_PIN C14 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {tmp_scl}]
set_property -dict { PACKAGE_PIN C15 IOSTANDARD LVCMOS33 PULLUP true } [get_ports {tmp_sda}]

## 4. Seven-segment display
## seg[0]=CA, seg[1]=CB, seg[2]=CC, seg[3]=CD
## seg[4]=CE, seg[5]=CF, seg[6]=CG

set_property -dict { PACKAGE_PIN T10 IOSTANDARD LVCMOS33 } [get_ports {seg[0]}]
set_property -dict { PACKAGE_PIN R10 IOSTANDARD LVCMOS33 } [get_ports {seg[1]}]
set_property -dict { PACKAGE_PIN K16 IOSTANDARD LVCMOS33 } [get_ports {seg[2]}]
set_property -dict { PACKAGE_PIN K13 IOSTANDARD LVCMOS33 } [get_ports {seg[3]}]
set_property -dict { PACKAGE_PIN P15 IOSTANDARD LVCMOS33 } [get_ports {seg[4]}]
set_property -dict { PACKAGE_PIN T11 IOSTANDARD LVCMOS33 } [get_ports {seg[5]}]
set_property -dict { PACKAGE_PIN L18 IOSTANDARD LVCMOS33 } [get_ports {seg[6]}]

## 5. Decimal point
set_property -dict { PACKAGE_PIN H15 IOSTANDARD LVCMOS33 } [get_ports {dp}]

## 6. Four-digit enables (active-low)
set_property -dict { PACKAGE_PIN J17 IOSTANDARD LVCMOS33 } [get_ports {an[0]}]
set_property -dict { PACKAGE_PIN J18 IOSTANDARD LVCMOS33 } [get_ports {an[1]}]
set_property -dict { PACKAGE_PIN T9 IOSTANDARD LVCMOS33 } [get_ports {an[2]}]
set_property -dict { PACKAGE_PIN J14 IOSTANDARD LVCMOS33 } [get_ports {an[3]}]

## 7. Status LEDs
## led[0] = I2C error
## led[1] = busy
set_property -dict { PACKAGE_PIN H17 IOSTANDARD LVCMOS33 } [get_ports {led[0]}]
set_property -dict { PACKAGE_PIN K15 IOSTANDARD LVCMOS33 } [get_ports {led[1]}]
