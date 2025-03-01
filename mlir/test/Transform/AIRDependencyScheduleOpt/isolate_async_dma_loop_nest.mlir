//===- isolate_async_dma_loop_nest.mlir ------------------------*- MLIR -*-===//
//
// Copyright (C) 2023, Advanced Micro Devices, Inc. All rights reserved.
// SPDX-License-Identifier: MIT
//
//===----------------------------------------------------------------------===//

// RUN: air-opt %s -air-isolate-async-dma-loop-nests | FileCheck %s

// Isolate scf for loops containing dma ops into perfectly nested loop.

// CHECK-LABEL: func0

// CHECK: air.launch
// CHECK: scf.for
// CHECK: air.channel.put{{.*}}@channel_1
// CHECK: air.channel.put{{.*}}@channel_1
// CHECK: scf.yield

// CHECK: air.segment @segment_0
// CHECK: scf.for
// CHECK: scf.parallel
// CHECK: air.channel.put{{.*}}@channel_2
// CHECK: scf.reduce
// CHECK: scf.yield
// CHECK: scf.yield

// CHECK: scf.for
// CHECK: scf.parallel
// CHECK: air.channel.get{{.*}}@channel_3
// CHECK: scf.reduce
// CHECK: scf.yield
// CHECK: scf.yield

// CHECK: scf.for
// CHECK: air.herd @herd_0
// CHECK: air.herd_terminator
// CHECK: scf.yield

// CHECK: %[[EVENT0:.*]]:4 = scf.for
// CHECK: air.channel.get{{.*}}@channel_1
// CHECK: air.channel.get{{.*}}@channel_1
// CHECK: air.channel.put{{.*}}@channel_0
// CHECK: air.channel.get{{.*}}@channel_1
// CHECK: air.channel.get{{.*}}@channel_1
// CHECK: air.channel.put{{.*}}@channel_0
// CHECK: scf.yield

// CHECK: air.segment_terminator

// CHECK: air.launch_terminator

module {
  air.channel @channel_3 [2, 2]
  air.channel @channel_2 [2, 2]
  air.channel @channel_1 [1, 1]
  air.channel @channel_0 [1, 1]
  func.func @func0(%extArg0: memref<32x32xi32>, %extArg1: memref<32x32xi32>, %extArg2: memref<32x32xi32>) {
    %c0 = arith.constant 0 : index
    %c1 = arith.constant 1 : index
    %c0_i32 = arith.constant 0 : i32
    %0 = air.launch async (%arg0, %arg1) in (%arg2=%c1, %arg3=%c1) args(%arg4=%extArg2, %arg5=%extArg0, %arg6=%extArg1) : memref<32x32xi32>, memref<32x32xi32>, memref<32x32xi32> attributes {id = 1 : i32} {
      %c8 = arith.constant 8 : index
      %c0_8 = arith.constant 0 : index
      %c1_9 = arith.constant 1 : index
      %c32 = arith.constant 32 : index
      %2 = air.wait_all async 
      %3 = scf.for %arg7 = %c0_8 to %c32 step %c8 iter_args(%arg8 = %2) -> (!air.async.token) {
        %6 = air.channel.put async [%arg8]  @channel_1[] (%arg5[] [] []) {id = 2 : i32} : (memref<32x32xi32>)
        %7 = air.channel.put async [%6]  @channel_1[] (%arg6[] [] []) {id = 3 : i32} : (memref<32x32xi32>)
        scf.yield %7 : !air.async.token
      }
      %5 = air.segment @segment_0 async  attributes {id = 2 : i32} {
        %c16 = arith.constant 16 : index
        %c1_22 = arith.constant 1 : index
        %c2 = arith.constant 2 : index
        %c0_23 = arith.constant 0 : index
        %c32_24 = arith.constant 32 : index
        %c8_25 = arith.constant 8 : index
        %6 = air.wait_all async 
        %async_token_26, %results_27 = air.execute -> (memref<32x32xi32, 1>) {
          %alloc = memref.alloc() : memref<32x32xi32, 1>
          air.execute_terminator %alloc : memref<32x32xi32, 1>
        }
        %8 = scf.for %arg7 = %c0_23 to %c32_24 step %c8_25 iter_args(%arg8 = %6) -> (!air.async.token) {
          %11 = air.herd @herd_0 async [%arg8]  tile (%arg9, %arg10) in (%arg11=%c2, %arg12=%c2) attributes {id = 3 : i32} {
            %async_token_37, %results_38 = air.execute -> (memref<32x32xi32, 2>) {
              %alloc = memref.alloc() : memref<32x32xi32, 2>
              air.execute_terminator %alloc : memref<32x32xi32, 2>
            }
            %15 = air.channel.get async [%async_token_37]  @channel_0[%arg9, %arg10] (%results_38[] [] []) {id = 14 : i32} : (memref<32x32xi32, 2>)
            %async_token_41, %results_42 = air.execute -> (memref<32x32xi32, 2>) {
              %alloc = memref.alloc() : memref<32x32xi32, 2>
              air.execute_terminator %alloc : memref<32x32xi32, 2>
            }
            %17 = air.channel.get async [%async_token_41]  @channel_2[%arg9, %arg10] (%results_42[] [] []) {id = 18 : i32} : (memref<32x32xi32, 2>)
            %async_token_43 = air.wait_all async [%15, %17]
            %18 = air.channel.put async [%async_token_43]  @channel_3[%arg9, %arg10] (%results_42[] [] []) {id = 19 : i32} : (memref<32x32xi32, 2>)
            %async_token_44 = air.execute [%async_token_43] {
              memref.dealloc %results_38 : memref<32x32xi32, 2>
            }
            %async_token_46 = air.execute [%18] {
              memref.dealloc %results_42 : memref<32x32xi32, 2>
            }
            air.herd_terminator
          }
          %12 = scf.parallel (%arg9, %arg10) = (%c0_23, %c0_23) to (%c2, %c2) step (%c1_22, %c1_22) init (%arg8) -> !air.async.token {
            %15 = air.channel.put async [%arg8]  @channel_2[%arg9, %arg10] (%results_27[] [] []) {id = 12 : i32} : (memref<32x32xi32, 1>)
            scf.reduce(%15)  : !air.async.token {
            ^bb0(%arg11: !air.async.token, %arg12: !air.async.token):
              %16 = air.wait_all async [%arg11, %arg12] 
              scf.reduce.return %16 : !air.async.token
            }
            scf.yield
          }
          %13 = scf.parallel (%arg9, %arg10) = (%c0_23, %c0_23) to (%c2, %c2) step (%c1_22, %c1_22) init (%arg8) -> !air.async.token {
            %15 = air.channel.get async [%arg8]  @channel_3[%arg9, %arg10] (%results_27[] [] []) {id = 13 : i32} : (memref<32x32xi32, 1>)
            scf.reduce(%15)  : !air.async.token {
            ^bb0(%arg11: !air.async.token, %arg12: !air.async.token):
              %16 = air.wait_all async [%arg11, %arg12] 
              scf.reduce.return %16 : !air.async.token
            }
            scf.yield
          }
          %14 = air.wait_all async [%11, %12, %13] 
          scf.yield %14 : !air.async.token
        } {unroll = 4 : i32}
        %async_token_28, %results_29 = air.execute [%6] -> (memref<32x32xi32, 1>) {
          %alloc = memref.alloc() : memref<32x32xi32, 1>
          air.execute_terminator %alloc : memref<32x32xi32, 1>
        }
        %async_token_30, %results_31 = air.execute [%async_token_28] -> (memref<32x32xi32, 1>) {
          %alloc = memref.alloc() : memref<32x32xi32, 1>
          air.execute_terminator %alloc : memref<32x32xi32, 1>
        }
        %async_token_32, %results_33 = air.execute [%async_token_30] -> (memref<32x32xi32, 1>) {
          %alloc = memref.alloc() : memref<32x32xi32, 1>
          air.execute_terminator %alloc : memref<32x32xi32, 1>
        }
        %async_token_34, %results_35 = air.execute [%async_token_30] -> (memref<32x32xi32, 1>) {
          %alloc = memref.alloc() : memref<32x32xi32, 1>
          air.execute_terminator %alloc : memref<32x32xi32, 1>
        }
        %9:4 = scf.for %arg7 = %c0_23 to %c32_24 step %c16 iter_args(%arg8 = %async_token_32, %arg9 = %async_token_34, %arg10 = %async_token_34, %arg11 = %async_token_34) -> (!air.async.token, !air.async.token, !air.async.token, !air.async.token) {
          %11 = air.wait_all async 
          %12 = air.channel.get async [%arg11, %async_token_32, %arg8]  @channel_1[] (%results_33[] [] []) {id = 6 : i32} : (memref<32x32xi32, 1>)
          %13 = air.channel.get async [%12, %arg11, %async_token_34, %arg8]  @channel_1[] (%results_35[] [] []) {id = 7 : i32} : (memref<32x32xi32, 1>)
          %14 = air.channel.put async [%arg10, %11]  @channel_0[] (%results_33[] [] []) {id = 8 : i32} : (memref<32x32xi32, 1>)
          %async_token_37 = air.execute {
            memref.dealloc %results_33 : memref<32x32xi32, 1>
          }
          %async_token_38 = air.execute {
            memref.dealloc %results_35 : memref<32x32xi32, 1>
          }
          %18 = air.wait_all async 
          %19 = air.channel.get async [%13, %11, %arg9]  @channel_1[] (%results_31[] [] []) {id = 6 : i32} : (memref<32x32xi32, 1>)
          %20 = air.channel.get async [%19, %13, %11, %arg9]  @channel_1[] (%results_29[] [] []) {id = 7 : i32} : (memref<32x32xi32, 1>)
          %21 = air.channel.put async [%13, %18]  @channel_0[] (%results_31[] [] []) {id = 8 : i32} : (memref<32x32xi32, 1>)
          %async_token_39 = air.execute {
            memref.dealloc %results_31 : memref<32x32xi32, 1>
          }
          %async_token_40 = air.execute {
            memref.dealloc %results_29 : memref<32x32xi32, 1>
          }
          scf.yield %13, %20, %20, %20 : !air.async.token, !air.async.token, !air.async.token, !air.async.token
        } {unroll = 2 : i32}
        %10 = air.wait_all async [%8, %9#1]
        %async_token_36 = air.execute [%10] {
          memref.dealloc %results_27 : memref<32x32xi32, 1>
        }
        air.segment_terminator
      }
      air.launch_terminator
    }
    return
  }
}
