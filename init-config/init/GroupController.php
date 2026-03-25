<?php

declare(strict_types=1);

namespace App\Controller\Crudit;

use App\Crudit\Config\GroupCrudConfig;
use Lle\CruditBundle\Controller\AbstractCrudController;
use Lle\CruditBundle\Controller\TraitCrudController;
use Symfony\Component\Routing\Attribute\Route;

#[Route('/group')]
class GroupController extends AbstractCrudController
{
    use TraitCrudController;

    public function __construct(GroupCrudConfig $config)
    {
        $this->config = $config;
    }
}
