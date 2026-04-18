package com.minejava.cartservice.controller;

import com.minejava.cartservice.model.Cart;
import com.minejava.cartservice.model.CartItem;
import com.minejava.cartservice.service.CartService;
import lombok.RequiredArgsConstructor;
import org.springframework.web.bind.annotation.*;

@RestController
@RequestMapping("/api/cart")
@RequiredArgsConstructor
public class CartController {
    private final CartService cartService;

    @GetMapping("/{userId}")
    public Cart getCart(@PathVariable String userId) {
        return cartService.getCart(userId);
    }

    @PostMapping("/{userId}/add")
    public Cart addItem(@PathVariable String userId, @RequestBody CartItem item) {
        System.err.println("Adding item to cart: " + item);
        return cartService.addItem(userId, item);
    }

    @DeleteMapping("/{userId}")
    public void clearCart(@PathVariable String userId) {
        cartService.clearCart(userId);
    }
}
