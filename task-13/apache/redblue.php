<?php

if (rand(0, 1)) {
    echo system('curl -v ' . getenv('RED_CONTAINER_URL'));
} else {
    echo system('curl -v ' . getenv('BLUE_CONTAINER_URL'));
}