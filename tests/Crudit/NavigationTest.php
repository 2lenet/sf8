<?php

namespace App\Tests\Crudit;

use App\Repository\UserRepository;
use Lle\CruditBundle\Test\TestHelperTrait;
use Symfony\Bundle\FrameworkBundle\Test\WebTestCase;

class NavigationTest extends WebTestCase
{
    use TestHelperTrait;

    public const EXCLUDED_ROUTES = [];

    public const LOGIN_USER = 'dev@2le.net';

    public const USER_REPOSITORY = UserRepository::class;
}
